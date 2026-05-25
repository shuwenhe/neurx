package neurx.include.agent_protocol

string AGENT_MSG_OBSERVATION = "observation"
string AGENT_MSG_ACTION = "action"
string AGENT_MSG_SIGNAL = "signal"
string AGENT_MSG_RESULT = "result"

struct agent_message_header {
    string session_id
    string task_id
    string message_type
    string source
}
