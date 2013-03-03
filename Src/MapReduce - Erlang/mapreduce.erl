-module(mapreduce).
-export([main/1]).

main(Input) ->
	% call master and pass as arguments Input and 2 functions: read_words and count_words
	Results = master(Input, fun read_words/2, fun count_words/2),
	lists:foreach(fun({Word, Count}) -> io:format("~p: ~p~n", [Word, Count]) end, Results),
	ok.



read_words(FileName, Emit) ->
	{ok, FileContent} = file:read_file(FileName),
	Words = string:tokens(erlang:binary_to_list(FileContent), " \t\n\r,.;:-!?\"'()"),
	lists:foreach(
		fun(Word) ->
			if
				Word /= "" -> Emit(Word, 1);
				Word == "" -> false
			end
		end, Words).



count_words({Word, Counts}, Emit) ->
	Emit(Word, length(Counts)).


% Master takes Input and 2 lambdas: Map-function and Reduce-function
master(Input, Map, Reduce) ->
	% run map
	MapCount = run_map(Input, Map),
	% collect map results and sort them using a lambda for comparison
	MapResults = lists:sort(
		fun({LeftKey, _}, {RightKey, _}) -> LeftKey =< RightKey end,
		wait_results(MapCount, [])),

	% run reduce
	ReduceCount = run_reduce(MapResults, Reduce),
	% collect results
	wait_results(ReduceCount, []).



run_map(Input, Fun) ->
	% for each elemt in list call a lambda which calls spawn_worker function
	lists:foreach(
		fun(Element) -> spawn_worker(Element, Fun) end, Input),
	length(Input).



run_reduce([{Key, Value} | SortedList], Fun) ->
	run_reduce(Key, [Value], SortedList, Fun, 0).


% This set of run_reduce functions groups the received sorted list by Key
% and calls spawn_worker for each pair {Key, ValuesList}
run_reduce(Key, ValueList,
		[{Key, Value} | SortedList], Fun, Count) ->
	run_reduce(Key, [Value | ValueList],
		SortedList, Fun, Count);

run_reduce(Key, ValueList,
		[{NewKey, Value} | SortedList], Fun, Count) ->
	spawn_worker({Key, ValueList}, Fun),
	run_reduce(NewKey, [Value], SortedList, Fun, Count + 1);

run_reduce(Key, ValueList, [], Fun, Count) ->
	spawn_worker({Key, ValueList}, Fun),
	Count + 1.



% Function which schedules a worker process.
% It receives an Element which should be processed and
% a worker function (Map or Reduce)
spawn_worker(Element, Fun) ->
	% get current PID
	Current = self(),

	% define 2 lambdas: Emit and Worker
	Emit =
		fun(Key, Val) ->
			Current ! {Key, Val}
		end,

	Worker =
		fun() ->
			% Worker calls the received function and pass Element
			% and Emit as an arguments
			Fun(Element, Emit),
			% notify parent that worker is done
			Current ! worker_done
		end,

	% schedule the worker process
	spawn(fun() -> Worker() end).



% This instance of wait_results is called when
% the 1st argument is 0 
wait_results(0, Results) ->
	Results;

% This instance of wait_results is called when
% the 1st element is not 0
wait_results(Count, Results) ->
	% wait for messages
	receive
		{Key, Val} ->
			% extend Results list with the received pair
			% and call wait_results recursively
			wait_results(Count, [{Key, Val} | Results]);
		worker_done ->
			% some worker is done: decrease count of
			% worker and call wait_results recursively
			wait_results(Count - 1, Results)
	end.
