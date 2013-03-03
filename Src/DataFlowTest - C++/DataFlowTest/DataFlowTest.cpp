// DataFlowTest.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"

#include <agents.h>
#include <iostream>
#include <fstream>
#include <map>
#include <memory>
#include <string>
#include <utility>
#include <time.h>

#include <Windows.h>

class command;
typedef std::shared_ptr<command> command_ptr;

class command
{
public:
	virtual ~command() { }

	const std::string& name() const
	{
		return name_;
	}

	virtual command_ptr clone(const std::string &arg) const = 0;

	virtual std::string execute() const = 0;

protected:
	explicit command(const std::string &name)
		: name_(name) { }

private:
	std::string name_;
};

// Usage: gettime [gmt]
class get_time : public command
{
public:
	static const get_time SAMPLE;

	virtual command_ptr clone(const std::string &arg) const
	{
		return command_ptr(new get_time(arg));
	}

	virtual std::string execute() const;

private:
	explicit get_time(const std::string &arg = "")
		: command("gettime"), gmt_("gmt" == arg),
		bad_argument_(!gmt_ && !arg.empty())
	{ }

	bool gmt_;
	bool bad_argument_;
};

const get_time get_time::SAMPLE;

std::string
get_time::execute() const
{
	if (bad_argument_) {
		return "Bad argument. Usage: gettime [gmt]";
	}

	time_t sys_time;
	if (-1 == time(&sys_time)) {
		return "Cannot obtain a system time";
	}

	tm current_time;
	errno_t error;
	if (gmt_) {
		error = gmtime_s(&current_time, &sys_time);
	} else {
		error = localtime_s(&current_time, &sys_time);
	}

	if (0 != error) {
		return "Cannot convert time";
	}

	char buffer[1024] = {0};
	if (0 != asctime_s(
		buffer, sizeof(buffer)/sizeof(buffer[0]),
		&current_time)) {
		return "Cannot print time";
	}

	return std::string(buffer);
}

// Usage: echo <text>
class echo : public command
{
public:
	static const echo SAMPLE;

	virtual command_ptr clone(const std::string &arg) const
	{
		return command_ptr(new echo(arg));
	}

	virtual std::string execute() const
	{
		return text_;
	}

private:
	explicit echo(const std::string &arg = "")
		: command("echo"), text_(arg) { }

	std::string text_;
};

const echo echo::SAMPLE;

class bad_command : public command
{
public:
	static const std::string NAME;

	explicit bad_command(const std::string line)
		: command(NAME), line_(line) { }

	virtual command_ptr clone(const std::string &arg) const
	{
		return command_ptr(new bad_command(arg));
	}

	virtual std::string execute() const
	{
		return std::string("Bad command: ") + line_;
	}
private:
	std::string line_;
};

const std::string bad_command::NAME = "abort";

// command_processor
class command_processor : public Concurrency::agent
{
	typedef std::map<std::string, const command*> commands_dict;

	// t_line::first - line
	// t_line::second - "end of file" flag
	typedef std::pair<std::string, bool> t_line;

	// t_command::first - command
	// t_command::second - "end of file" flag
	typedef std::pair<command_ptr, bool> t_command;

public:
	explicit command_processor(std::istream &input);

	virtual ~command_processor()
	{
		Concurrency::agent::wait(this);
	}

	static void register_command(
		const std::string &name, const command *cmd)
	{
		COMMANDS[name] = cmd;
	}

	std::string read(bool &next)
	{
		// Read results from output_.
		// This operation blocks a thread if output_ is empty.
		std::pair<std::string, bool> out =
			Concurrency::receive(output_);
		next = out.second;
		return out.first;
	}

protected:
	void run();

private:
	static t_line run_command(const t_command &command);
	static t_command parse_command(const t_line &line);

	static commands_dict COMMANDS;

	std::istream &input_;

	// receive: t_line
	Concurrency::unbounded_buffer<t_line> output_;

	// receive: t_comand; send: t_line - result
	Concurrency::transformer<t_command, t_line> runner_;
	
	// receive: t_line - unparsed command; send: t_command
	Concurrency::transformer<t_line, t_command> parser_;
};

command_processor::command_processor(std::istream &input)
	: input_(input),
	// the output buffer:
	output_(),
	// the run step is linked with the output buffer:
	runner_(run_command, &output_),
	// the execute step is linked with the run step:
	parser_(parse_command, &runner_)
{ }

void command_processor::run()
{
	std::string line;
	do 
	{
		char ch = L'\0';
		input_.get(ch);

		if (ch == '\n' || input_.eof()) {
			// send line to parser
			t_line new_line = std::make_pair(
				line, !input_.eof());

			Concurrency::asend(
				parser_, new_line);

			line.clear();
		} else if (input_.good()) {
			line += ch;
		} else {
			// send "bad command" to parser and stop processing
			t_line abort_line = std::make_pair(
				bad_command::NAME, false);
			Concurrency::asend(
				parser_, abort_line);
		}
	} while (input_ != 0);

	done();
}

command_processor::t_command
command_processor::parse_command(
	const command_processor::t_line &line)
{
	// detect the command's name
	size_t pos = line.first.find_first_of(" \t");
	const std::string name = line.first.substr(0, pos);
	
	// detect the command's arguments
	pos = line.first.find_first_not_of(" \t", pos);
	const std::string arg = std::string::npos == pos
		? std::string() : line.first.substr(pos);

	// get the command object
	commands_dict::const_iterator it = COMMANDS.find(name);
	if (COMMANDS.end() != it) {
		return std::make_pair(
			it->second->clone(arg), line.second);
	}

	// bad command
	return std::make_pair(
		command_ptr(new bad_command(line.first)),
		line.second);
}

command_processor::t_line
command_processor::run_command(
	const command_processor::t_command &command)
{
	return std::make_pair(
		command.first->execute(), command.second);
}

command_processor::commands_dict
	command_processor::COMMANDS;

int _tmain(int argc, _TCHAR* argv[])
{
	if (argc != 2) {
		return -1;
	}

	const std::wstring filename = argv[1];

	std::ifstream data;
	data.exceptions(std::ios::badbit);
	data.open(filename);

	command_processor::register_command(
		get_time::SAMPLE.name(), &get_time::SAMPLE);
	command_processor::register_command(
		echo::SAMPLE.name(), &echo::SAMPLE);

	command_processor processor(data);
	processor.start();

	bool next;
	do {
		std::cout << processor.read(next) << std::endl;
	} while (next);

	return 0;
}
