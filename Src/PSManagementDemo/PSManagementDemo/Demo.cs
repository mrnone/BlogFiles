using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.Reflection;
using System.IO;
using System.Management.Automation.Runspaces;
using System.Management.Automation;
using System.Collections;

namespace PSManagementDemo
{
    public partial class Demo : Form
    {
        public Demo()
        {
            InitializeComponent();
        }

        private void Form1_Load(object sender, EventArgs e)
        {
            LoadScripts();
        }

        private void LoadScripts()
        {
            var files = from file in Directory.EnumerateFiles(ScriptsLocation, "*.ps1")
                        orderby file
                        select Path.GetFileNameWithoutExtension(file);

            procedures.Items.Clear();
            procedures.Items.AddRange(files.ToArray());

            if (procedures.Items.Count > 0)
            {
                procedures.SelectedIndex = 0;
            }
        }

        private static string ScriptsLocation
        {
            get
            {
                return Path.Combine(
                    Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location), "scripts");
            }
        }

        private void refresh_Click(object sender, EventArgs e)
        {
            LoadScripts();
        }

        private void call_Click(object sender, EventArgs e)
        {
            if (procedures.SelectedIndex != -1)
            {
                string scriptLocation = Path.Combine(
                    ScriptsLocation,
                    procedures.Items[procedures.SelectedIndex].ToString() + ".ps1");

                string script;
                using (StreamReader file = new StreamReader(scriptLocation))
                {
                    script = file.ReadToEnd();
                }

                Hashtable args = new Hashtable();

                foreach (string line in arguments.Lines)
                {
                    string[] pair = line.Split(new char[] { '=' }, 2);
                    args.Add(pair[0], pair.Length > 1 ? pair[1] : String.Empty);
                }

                results.Lines = Call(script, args).ToArray();
            }
        }

        private IEnumerable<string> Call(string script, Hashtable args)
        {
            InitialSessionState state = InitialSessionState.CreateDefault();
            state.Variables.Add(new SessionStateVariableEntry("ErrorActionPreference", "Stop", null));
            state.Variables.Add(new SessionStateVariableEntry("Arguments", args, null));
            using (Runspace runspace = RunspaceFactory.CreateRunspace(state))
            {
                runspace.Open();
                using (PowerShell shell = PowerShell.Create())
                {
                    shell.Runspace = runspace;
                    shell.AddScript("Set-PSDebug -Strict\n" + script);
                    try
                    {
                        return new List<string>(from PSObject obj in shell.Invoke()
                            where obj != null select obj.ToString());
                    }
                    catch (RuntimeException psError)
                    {
                        ErrorRecord error = psError.ErrorRecord;
                        return error.InvocationInfo == null ? FormatErrorSimple(error.Exception)
                            : FormatError(error.InvocationInfo, error.Exception);
                    }
                }
            }
        }

        private IEnumerable<string> FormatError(InvocationInfo invocationInfo, Exception exception)
        {
            return new string[] {
                String.Format("{0} : {1}", invocationInfo.InvocationName, exception.Message),
                invocationInfo.PositionMessage
            };
        }

        private IEnumerable<string> FormatErrorSimple(Exception exception)
        {
            return new string[] { exception.Message };
        }
    }
}
