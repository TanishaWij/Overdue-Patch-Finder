import ballerina/io;
import ballerina/sql;
import ballerina/mysql;
import wso2/gmail;
import ballerina/http;
import ballerina/log;
import ballerina/config;
import ballerina/test;

@Description {value:"Number of days a patch can be in development."}
@final int NUM_DAYS = 1;

@final string BACKGROUND_COLOR_GRAY = "#efefef";
@final string BACKGROUND_COLOR_WHITE = "#ffffff";

//setting up gmail connector endpoint
string accessToken = config:getAsString("ACCESS_TOKEN");
string clientId = config:getAsString("CLIENT_ID");
string clientSecret = config:getAsString("CLIENT_SECRET");
string refreshToken = config:getAsString("REFRESH_TOKEN");

endpoint gmail:Client gMailEP {
    clientConfig:{
        auth:{
            accessToken:accessToken,
            clientId:clientId,
            clientSecret:clientSecret,
            refreshToken:refreshToken
        }
    }
};

//setting up mysql endpoint
string host = config:getAsString("HOST");
int port = config:getAsInt("PORT");
string name = config:getAsString("NAME");
string username = config:getAsString("USERNAME");
string password = config:getAsString("PASSWORD");

endpoint mysql:Client pmtDB {
    host: host,
    port:port,
    name:name+"?useSSL=false",
    username:username,
    password:password,
    poolOptions:{maximumPoolSize:5}
};


public function main (string[] args) {
    table data = getDataFromDB();
    string htmlEmailBody = generateHtmlTable(data);
    //printEmail(htmlEmailBody);
    //sendMail(htmlEmailBody);
    //closing connection pool
    _ = pmtDB -> close();

}


@Description {value:"This function acesses DB and gets data on overdue patches"}
function getDataFromDB() returns (table){
    sql:Parameter maxDaysInDev = (sql:TYPE_INTEGER, NUM_DAYS);
    string numWorkDaysCalc ="(5 * (DATEDIFF(CURDATE(), q.REPORT_DATE) DIV 7) + MID('0123455401234434012332340122123401101234000123450', 7 * WEEKDAY((q.REPORT_DATE)) + WEEKDAY(CURDATE()) + 1, 1))";

    table dt = check pmtDB -> select("SELECT e.PATCH_NAME, e.LAST_UPDATED_USER, date(e.DEVELOPMENT_STARTED_ON) AS DEV_START_ON, q.REPORT_DATE, "
            + numWorkDaysCalc + " AS DAYS_IN_DEV,
             DATEDIFF(e.DEVELOPMENT_STARTED_ON, q.REPORT_DATE) AS DAYS_IN_QUEUE
            FROM PATCH_ETA e JOIN PATCH_QUEUE q ON e.PATCH_QUEUE_ID = q.ID
            WHERE RELEASED_ON IS NULL AND RELEASED_NOT_AUTOMATED_ON IS NULL AND RELEASED_NOT_IN_PUBLIC_SVN_ON IS NULL
            AND LC_STATE NOT IN ('ReleasedNotInPublicSVN', 'ReleasedNotAutomated', 'Released', 'Staging', 'OnHold')
            AND YEAR(e.DEVELOPMENT_STARTED_ON) > '2017'
            AND" + numWorkDaysCalc +">?", null, maxDaysInDev);

    //table results = check pmtDB -> call("CALL get_overdue_patches(?)", null, maxDaysInDev);

    return dt;

}


@Description {value:"Generate html content for overdue patch information table"}
function generateHtmlTable (table patchInfo) returns (string) {

    string htmlTable = "<table align=\"center\" cellspacing=\"0\" cellpadding=\"0\" border=\"0\" width=\"95%\">" +
    "<tr>" +
    " <td width=\"33%\" align=\"center\" color=\"#044767\" bgcolor=\"#bebebe\" style=\"font-family: Open Sans, Helvetica, Arial, sans-serif; font-size: 14px; font-weight: 800; line-height: 20px; padding: 10px;\">" +
    "Patch Name" +
    " </td>" +
    "<td width=\"11%\" align=\"center\" color=\"#044767\" bgcolor=\"#bebebe\" style=\"font-family: Open Sans, Helvetica, Arial, sans-serif; font-size: 14px; font-weight: 800; line-height: 20px; padding: 10px;\">" +
    "Reported Date" +
    "</td>" +
    "<td width=\"30%\" align=\"center\" color=\"#044767\" bgcolor=\"#bebebe\" style=\"font-family: Open Sans, Helvetica, Arial, sans-serif; font-size: 14px; font-weight: 800; line-height: 20px; padding: 10px;\">" +
    "Engineer" +
    "</td>" +
    "<td width=\"6%\" align=\"center\" color=\"#044767\" bgcolor=\"#bebebe\" style=\"font-family: Open Sans, Helvetica, Arial, sans-serif; font-size: 14px; font-weight: 800; line-height: 20px; padding: 10px;\">" +
    "Development Start Date" +
    "</td>" +
    " <td width=\"6%\" align=\"center\" color=\"#044767\" bgcolor=\"#bebebe\" style=\"font-family: Open Sans, Helvetica, Arial, sans-serif; font-size: 14px; font-weight: 800; line-height: 20px; padding: 10px;\">" +
    "Days In Queue" +
    "</td>" +
    "<td width=\"6%\" align=\"center\" color=\"#044767\" bgcolor=\"#bebebe\" style=\"font-family: Open Sans, Helvetica, Arial, sans-serif; font-size: 14px; font-weight: 800; line-height: 20px; padding: 10px;\">" +
    "Days In Development" +
    "</td>" +
    "</tr>";

    string rowValues = outdatedPatchInformation(patchInfo);
    htmlTable += rowValues;
    htmlTable +=  "</table>";
    return htmlTable;
}


@Description {value:"This function takes a table and returns the information in HTML as a String"}
function outdatedPatchInformation (table patchInfo) returns (string) {
    var j = check <json>patchInfo;
    string patchInfoToString = "";
    boolean toggleFlag = true;
    string backgroundColor;
    ///json objects to string
    foreach x in j {
        if (toggleFlag) {
            backgroundColor = BACKGROUND_COLOR_WHITE;
            toggleFlag = false;
        }
        else {
            backgroundColor = BACKGROUND_COLOR_GRAY;
            toggleFlag = true;
        }

        json startDate = (x.DEV_START_ON);
        string startDateStr = startDate.toString() but {error=>"-"};

        json updatedBy = (x.LAST_UPDATED_USER);
        string updatedByStr = updatedBy.toString() but {error=>"-"};

        json patchName = (x.PATCH_NAME);
        string patchNameStr = patchName.toString() but {error=>"-"};

        json daysInDev = (x.DAYS_IN_DEV);
        //int daysInDevInt = <int>daysInDev but {error=> 10000};
        string daysInDevStr = (daysInDev.toString() but {error=>"0.0"});

        json daysInQueue = (x.DAYS_IN_QUEUE);
        string daysIntQueueStr = daysInQueue.toString() but {error=>"-"};

        json reportDate = (x.REPORT_DATE);
        string reportDateStr = reportDate.toString() but {error=>"-"};

        patchInfoToString += "<tr><td width=\"" + "33%" + "\" align=\"center\" bgcolor=" + backgroundColor + " style=\"font-family: Open Sans, Helvetica, Arial, sans-serif; font-size: 14px; font-weight: 400; line-height: 20px; padding: 15px 10px 5px 10px;\">" +
            patchNameStr + "<td width=\"" + "11%" + "\" align=\"center\" bgcolor=" + backgroundColor + " style=\"font-family: Open Sans, Helvetica, Arial, sans-serif; font-size: 14px; font-weight: 400; line-height: 20px; padding: 15px 10px 5px 10px;\">" +
            reportDateStr + "<td width=\"" + "30%" + "\" align=\"center\" bgcolor=" + backgroundColor + " style=\"font-family: Open Sans, Helvetica, Arial, sans-serif; font-size: 14px; font-weight: 400; line-height: 20px; padding: 15px 10px 5px 10px;\">" +
            updatedByStr + "<td width=\"" + "6%" + "\" align=\"center\" bgcolor=" + backgroundColor + " style=\"font-family: Open Sans, Helvetica, Arial, sans-serif; font-size: 14px; font-weight: 400; line-height: 20px; padding: 15px 10px 5px 10px;\">" +
            startDateStr + "<td width=\"" + "6%" + "\" align=\"center\" bgcolor=" + backgroundColor + " style=\"font-family: Open Sans, Helvetica, Arial, sans-serif; font-size: 14px; font-weight: 400; line-height: 20px; padding: 15px 10px 5px 10px;\">" +
            daysIntQueueStr+ "<td width=\"" + "6%" + "\" align=\"center\" bgcolor=" + backgroundColor + " style=\"font-family: Open Sans, Helvetica, Arial, sans-serif; font-size: 14px; font-weight: 400; line-height: 20px; padding: 15px 10px 5px 10px;\">" +
            daysInDevStr;
    }
    return patchInfoToString;
}



@Description {value:"This function takes a string and prints it."}
function printEmail (string body) {
    string email = "The following patches have been in development for more than "+ NUM_DAYS + " day.\n";
    email += body;
    io:println(email);
}


//@Description {value:"This function takes a string containing HTML and constructs and sends an email."}
//function sendtMail(string messageBody) {
//    string recipient = config:getAsString("RECIPIENT");
//    string sender = config:getAsString("SENDER");
//    string subject = "Overdue-patches";
//
//    string userId = "me";
//    string sentTextMailId;
//    //Thread id of text mail which will be sent from testSendSimpleMail()
//    string sentTextMailThreadId;
//    gmail:MessageOptions options = {};
//    options.sender = sender;
//    gmail:Message m = new;
//    m.createHTMLMessage(recipient, subject, messageBody, options,[]);
//    var sendMessageResponse = gMailEP -> sendMessage(userId, m);
//    string messageId;
//    string threadId;
//    match sendMessageResponse {
//        (string, string)sendStatus => {
//            (messageId, threadId) = sendStatus;
//             io:println(messageId);
//        }
//        gmail:GMailError e => io:println(e);
//    }
//}