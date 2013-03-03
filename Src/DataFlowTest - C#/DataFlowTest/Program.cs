using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Threading.Tasks.Dataflow;

namespace DataFlowTest
{
    class Program
    {
        static void Main(string[] args)
        {
            if (args.Length != 1)
            {
                System.Console.Error.WriteLine("Usage: DataFlowTest.exe <file_name>");
                return;
            }

            string fileName = args[0];

            // Fill list of supported commands
            Dictionary<string, Type> commands = new Dictionary<string, Type>();
            commands.Add(GetTime.Name, typeof(GetTime));
            commands.Add(Echo.Name, typeof(Echo));

// prepare the cancelation
CancellationTokenSource toCancel = new CancellationTokenSource();

            // create "parser" block
            TransformBlock<string, ICommand> parser =
                new TransformBlock<string, ICommand>(
                line =>
                {
                    if (string.IsNullOrEmpty(line))
                    {
                        ICommand bad = new BadCommand();
                        bad.Arguments = "<EMPTY>";
                        return bad;
                    }

                    string [] tokens = line.Split(
                        new char[] { ' ', '\t' }, 2);

                    Type commandType;
                    if (!commands.TryGetValue(
                        tokens[0], out commandType))
                    {
                        ICommand bad = new BadCommand();
                        bad.Arguments = line;
                        return bad;
                    }

                    ICommand command = (ICommand)
                        Activator.CreateInstance(commandType);
                    command.Arguments =
                        tokens.Length == 2 ? tokens[1] : null;

                    return command;
                }, new ExecutionDataflowBlockOptions {
                    CancellationToken = toCancel.Token });

            // create "executor" block
            TransformBlock<ICommand, string> executor =
                new TransformBlock<ICommand, string>(
                command => command.Execute(),
                new ExecutionDataflowBlockOptions {
                    CancellationToken = toCancel.Token });

            // create "printer" block
            ActionBlock<string> printer =
                new ActionBlock<string>(
                result => System.Console.WriteLine(result),
                new ExecutionDataflowBlockOptions {
                    CancellationToken = toCancel.Token });

            // link blocks together
            parser.LinkTo(executor);
            executor.LinkTo(printer);

            // add "complete" condition
            parser.Completion.ContinueWith(
                finishedTask =>
                {
                    if (finishedTask.IsFaulted)
                    {
                        // pass the fault reason to the next block
                        ((IDataflowBlock)executor).Fault(
                            finishedTask.Exception);
                    }
                    else
                    {
                        // tranfer "complete" command to the next block
                        executor.Complete();
                    }
                });

            executor.Completion.ContinueWith(
                finishedTask =>
                {
                    if (finishedTask.IsFaulted)
                    {
                        // pass the fault reason to the next block
                        ((IDataflowBlock)printer).Fault(
                            finishedTask.Exception);
                    }
                    else
                    {
                        // tranfer "complete" command to the next block
                        printer.Complete();
                    }
                });

            Task printerFinish = printer.Completion.ContinueWith(
                finishedTask =>
                {
                    if (finishedTask.IsFaulted)
                    {
                        // cancel all in case of error
                        toCancel.Cancel();
                    }
                });

            using(StreamReader input = File.OpenText(fileName))
            {
                CancellationToken cancel = toCancel.Token;

                // read lines
                for (string line = input.ReadLine();
                    line != null && !cancel.IsCancellationRequested;
                    line = input.ReadLine())
                {
                    // transfer next line to the parser
                    parser.Post(line);
                }

                // mark block as completed
                parser.Complete();
            }

            // wait both: printer block and its continuation
            Task.WaitAll(printer.Completion, printerFinish);
        }
    }
}
