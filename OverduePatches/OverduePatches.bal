import ballerina/io;
import ballerina/sql;
import ballerina/task;
import ballerina/math;
import ballerina/log;

@Description {value:"Number of days a patch can be in development."}
const int NUM_DAYS = 1;

//TODO: wrap user credentials in config file
endpoint sql:Client pmtDB {
    database:sql:DB.MYSQL,
    host:"localhost",
    port:3306,
    name:"pmtdb",
    username:"root",
    password:"sajay123",
    options:{maximumPoolSize:5}
};


@Description {value:"This function takes a string argument as the emaiil body."}
function printEmail (string body) {
    string email = "The following patches have been in development for more than"+ NUM_DAYS + " day.\n";
    email += body;
    io:println(email);
}

@Description {value:"This function takes a table, extracts the overdue patch's information and returns it as a String"}
function outdatedPatchInformation (table patchInfo) returns (string) {
    //string jsonRes;
    var j =? <json>patchInfo;
    string patchInfoToString = "";
    ///json objects to string
    foreach x in j {
        json patchName = (x.PATCH_NAME);
        json startDate = (x.DEVELOPMENT_STARTED_ON);

        json updatedBy = (x.LAST_UPDATED_USER);
        patchInfoToString += ("Patch Name: " + patchName.toString()+ ", Started on: " + startDate.toString() +
                              ", Created by: " + updatedBy.toString() +".\n");
    }
    return patchInfoToString;
}


@Description {value:"This function acesses DB and gets data on overdue patches"}
function dbDataExtraction() returns (table){
    sql:Parameter[] maxDaysInDev = [{sqlType:sql:Type.INTEGER, value:NUM_DAYS}];
    string numWordDaysCalc ="(5 * (DATEDIFF(CURDATE(), PATCH_QUEUE.REPORT_DATE) DIV 7) + MID('0123455401234434012332340122123401101234000123450', 7 * WEEKDAY((PATCH_QUEUE.REPORT_DATE)) + WEEKDAY(CURDATE()) + 1, 1))";
    table dt =? pmtDB -> select("SELECT PATCH_ETA.PATCH_NAME, PATCH_ETA.LAST_UPDATED_USER, PATCH_ETA.DEVELOPMENT_STARTED_ON,
                           PATCH_QUEUE.REPORT_DATE," + numWordDaysCalc + "AS DATE_DIFF
                        FROM PATCH_ETA JOIN PATCH_QUEUE ON PATCH_ETA.PATCH_QUEUE_ID = PATCH_QUEUE.ID
                        WHERE RELEASED_ON IS NULL AND RELEASED_NOT_AUTOMATED_ON IS NULL AND RELEASED_NOT_IN_PUBLIC_SVN_ON IS NULL
                        AND LC_STATE NOT IN ('ReleasedNotInPublicSVN', 'ReleasedNotAutomated', 'Released', 'Staging', 'OnHold')
                        AND YEAR(PATCH_ETA.DEVELOPMENT_STARTED_ON) > '2017'
                        AND " + numWordDaysCalc +">?", maxDaysInDev, null);

    return dt;

}


public function main (string[] args) {
    table dt = dbDataExtraction();
    string emailBody = outdatedPatchInformation(dt);
    printEmail(emailBody);

    //closing connection pool



    _ = pmtDB -> close();

}
