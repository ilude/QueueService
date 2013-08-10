using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Linq;
using System.ServiceProcess;
using System.Text;
using System.Threading;
using System.Data.SqlClient;
using System.Xml;
using System.Transactions;

namespace QueueService
{
  public partial class Service1 : ServiceBase
  {
    bool running;

    public Service1()
    {
      InitializeComponent();
      running = true;
    }

    public void StartService()
    {
      OnStart(null);
    }

    public void StopService()
    {
      OnStop();
    }

    protected override void OnStart(string[] args)
    {
      using (var con = new SqlConnection("Data Source=(local);Initial Catalog=ServiceBrokerTest;Integrated Security=true"))
      {
        con.Open();
        while (running)
        {

          //string commandText = "WAITFOR ( RECEIVE TOP(1) CONVERT(NVARCHAR(MAX), message_body) AS Message FROM SBReceiveQueue);";
          string commandText = "WAITFOR ( RECEIVE TOP(1) message_body AS Message FROM SBReceiveQueue);";

          using(TransactionScope tran = new TransactionScope())
          using (SqlCommand command = new SqlCommand(commandText, con))
          {
            command.CommandTimeout = 1;
            try
            {

              using (SqlDataReader reader = command.ExecuteReader())
              {
                while (reader.Read())
                {
                  //Console.Out.WriteLine("[{0}] Message Received => {1} <=!", DateTime.Now.ToString("o"), reader.GetValue(reader.GetOrdinal("Message")));

                  //Console.Out.WriteLine("[{0}] Message Received => {1} <=!", DateTime.Now.ToString("o"), Encoding.Unicode.GetString(reader.GetValue(reader.GetOrdinal("Message")) as byte[]));
                  var data = Encoding.Unicode.GetString(reader.GetValue(reader.GetOrdinal("Message")) as byte[]).Substring(1);
                  Console.WriteLine(data);
                  XmlReader xmlReader = new XmlTextReader(new System.IO.StringReader(data));

                  //xmlReader.MoveToContent();
                  while (xmlReader.Read())
                  {
                    if (xmlReader.NodeType == XmlNodeType.Element)
                    {
                      string tableName = xmlReader.LocalName;
                      Console.WriteLine("Table  {0}", tableName);
                      for (int attInd = 0; attInd < xmlReader.AttributeCount; attInd++)
                      {
                        xmlReader.MoveToAttribute(attInd);
                        string columnName = xmlReader.LocalName;
                        string value = xmlReader.Value;
                        Console.WriteLine("\t{0} = {1}", columnName, value);
                      }
                    }
                  }

                  //for (int i = 0; i < reader.FieldCount; i++)
                  //{
                  //  Console.Out.WriteLine("\t{0}[{2}] - {3}: {1}", reader.GetName(i), reader.GetValue(i), i, reader.GetDataTypeName(i));
                  //}
                  //var message = reader.GetSqlBinary(reader.GetOrdinal("Message"));
                  //var body = Encoding.UTF32.GetString(message.Value);
                  //Console.Out.WriteLine("{1} - [{0}] ", body, message.Length);
                }
                
              }
              tran.Complete();
            }
            catch (SqlException ex)
            {
              if(!ex.Message.Contains("Timeout")) {
                Console.Out.WriteLine(ex);
                tran.Complete();
              }
              
            } 
          }
        }
        con.Close();
      }
      //RECEIVE TOP(1) CONVERT(NVARCHAR(MAX), message_body) AS Message
      //FROM SBReceiveQueue
    }

    protected override void OnStop()
    {
      running = false;
    }
  }
}
