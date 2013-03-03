using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataFlowTest
{
    internal interface ICommand
    {
        string Execute();

        string Arguments { get; set; }
    }

    // Usage: gettime [gmt]
    internal class GetTime : ICommand
    {
        public GetTime()
        {
        }

        public string Execute()
        {
            if (string.IsNullOrEmpty(Arguments))
            {
                return DateTime.Now.ToString();
            }
            else if (Arguments == "utc")
            {
                return DateTime.UtcNow.ToString();
            }
            else
            {
                return "Bad argument. Usage: gettime [utc]";
            }
        }

        public string Arguments { get; set; }

        public static string Name
        {
            get { return "gettime"; }
        }
    }

    // Usage: echo <text>
    internal class Echo : ICommand
    {
        public Echo()
        {
        }

        public string Execute()
        {
            if (string.IsNullOrEmpty(Arguments))
            {
                return "Bad argument. Usage: echo <text>";
            }

            return Arguments;
        }

        public string Arguments { get; set; }

        public static string Name
        {
            get { return "echo"; }
        }
    }

    // Representation of a bad command
    internal class BadCommand : ICommand
    {
        public BadCommand()
        {
        }

        public string Execute()
        {
            return "Bad command: " + Arguments;
        }

        public string Arguments { get; set; }
    }

}
