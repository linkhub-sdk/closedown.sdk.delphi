(*
*=================================================================================
* Unit for base module for Closedown API SDK. It include base functionality for
* RESTful web service request and parse json result. It uses Linkhub module
* to accomplish authentication APIs.
*
* http://linkhub.co.kr
* Author : Jeong Yohan (yhjeong@linkhub.co.kr)
* Written : 2015-06-17
* Thanks for your interest.
*=================================================================================
*)

unit Closedown;

interface
uses
        Windows, Messages, TypInfo, SysUtils, Classes,ComObj,ActiveX, Linkhub;

{$IFDEF VER240}
{$DEFINE COMPILER15_UP}
{$ENDIF}
{$IFDEF VER250}
{$DEFINE COMPILER15_UP}
{$ENDIF}
{$IFDEF VER260}
{$DEFINE COMPILER15_UP}
{$ENDIF}
{$IFDEF VER270}
{$DEFINE COMPILER15_UP}
{$ENDIF}
{$IFDEF VER280}
{$DEFINE COMPILER15_UP}
{$ENDIF}
const
        ServiceID = 'CLOSEDOWN';
        ServiceURL = 'https://closedown.linkhub.co.kr';
        APIVersion = '1.0';
        CR = #$0d;
        LF = #$0a;
        CRLF = CR + LF;
type
        TResponse = Record
                code : LongInt;
                message : string;
        end;

        TCorpState = class
        public
                corpNum : string;
                ctype : string;
                state : string;
                stateDate : string;
                checkDate : string;
        end;

        TCorpStateList = Array Of TCorpState;

        TClosedownChecker = class

        private
                function jsonToTCorpState(json : String) : TCorpState;

        protected
                FToken  : TToken;
                FAuth   : TAuth;
                FScope  : Array Of String;

                function getSession_Token() : String;
                function httpget(url : String) : String;
                function httppost(url : String; request : String) : String;

        public
                constructor Create(LinkID : String; SecretKey : String);
                function GetBalance() : Double;
                function GetUnitCost() : Single;
                function checkCorpNum(CorpNum : String) : TCorpState;
                function checkCorpNums(CorpNumList : Array Of String) : TCorpStateList;
        end;

        EClosedownException = class(Exception)

        private
                FCode : LongInt;
        public
                constructor Create(code : LongInt; Message : String);
        published
                property code : LongInt read FCode write FCode;

        end;

implementation


constructor EClosedownException.Create(code : LongInt; Message : String);
begin
    inherited Create(Message);
    FCode := code;
end;

constructor TClosedownChecker.Create(LinkID : String; SecretKey : String);
begin
        FAuth := TAuth.Create(LinkID, SecretKey);
        setLength(FScope, 1);
        FScope[0] := '170';
end;


function TClosedownChecker.getSession_Token() : String;
var
        noneOrExpired : bool;
        Expiration : TDateTime;
begin
        if FToken = nil then noneOrExpired := true
        else begin
                Expiration := UTCToDate(FToken.expiration);
                noneOrExpired := expiration < UTCToDate(FAuth.getTime());
        end;

        if noneOrExpired then
        begin
                try
                        FToken := FAuth.getToken(ServiceID,'',FScope);
                except on le:ELinkhubException do
                        raise EClosedownException.Create(le.code,le.message);
                end;
        end;
        result := FToken.session_token;
end;

function TClosedownChecker.httpget(url : String) : String;
var
        http : olevariant;
        response : string;
        sessiontoken : string;
begin
        url := ServiceURL + url;

        http:=createoleobject('MSXML2.XMLHTTP.6.0');
        http.open('GET',url);

        sessiontoken := getSession_Token();

        http.setRequestHeader('Authorization', 'Bearer ' + sessiontoken);
        http.setRequestHeader('x-api-version', APIVersion);
        http.setRequestHeader('Accept-Encoding','gzip,deflate');

        http.send;

        response := http.responsetext;
        if http.Status <> 200 then
        begin
            raise EClosedownException.Create(getJSonInteger(response,'code'),getJSonString(response,'message'));
        end
        else
        begin
            result := response;
        end;

end;

function TClosedownChecker.httppost(url : String; request : String) : String;
var
        http : olevariant;
        postdata : olevariant;
        response : string;
        sessiontoken : string;
     
begin
        postdata := request;
        http:=createoleobject('WinHttp.WinHttpRequest.5.1');
        http.open('POST',ServiceURL + url);

        sessiontoken := getSession_Token();
        HTTP.setRequestHeader('Authorization', 'Bearer ' + sessiontoken);

        HTTP.setRequestHeader('x-api-version',APIVersion);

        HTTP.setRequestHeader('Content-Type','Application/json ;');

        http.send(postdata);
        http.WaitForResponse;

        response := http.responsetext;

        if HTTP.Status <> 200 then
        begin
                raise EClosedownException.Create(getJSonInteger(response,'code'),getJSonString(response,'message'));
        end;
        
        result := response;
end;




function TClosedownChecker.jsonToTCorpState(json : String) : TCorpState;
var
        tmp : Variant;
begin
        result := TCorpState.Create;

        if Length(getJsonString(json, 'corpNum')) > 0 then
        begin
                result.corpNum := getJsonString(json, 'corpNum');
        end;

        if Length(getJsonString(json, 'type')) > 0  then
        begin
                result.ctype := getJsonString(json, 'type');
        end;

        if Length(getJsonString(json, 'state')) > 0 then
        begin
                result.state := getJsonString(json, 'state');
        end;

        if Length(getJsonString(json, 'stateDate')) > 0  then
        begin
               result.stateDate := getJsonString(json, 'stateDate');
        end;

        if Length(getJsonString(json, 'checkDate')) > 0 then
        begin
              result.checkDate := getJsonString(json, 'checkDate');
        end;
end;

function TClosedownChecker.GetBalance() : Double;
begin
        result := FAuth.getPartnerBalance(getSession_Token(),ServiceID);
end;

function TClosedownChecker.GetUnitCost() : Single;
var
        responseJson : string;

begin
        responseJson := httpget('/UnitCost');

        result := strToFloat(getJsonString(responseJson,'unitCost'));
end;

function TClosedownChecker.checkCorpNum(CorpNum : String) : TCorpState;
var
        responseJson : string;
        url : string;
begin
        if Length(corpNum) = 0 then
        begin
                raise EClosedownException.Create(-99999999, '사업자번호가 입력되지 않았습니다');
                Exit;
        end;

        url := '/Check?CN='+ CorpNum;

        responseJson := httpget(url);

        result := jsonToTCorpState(responseJson);
end;


function TClosedownChecker.checkCorpNums(CorpNumList : Array Of String) : TCorpStateList;
var
        requestJson : string;
        responseJson : string;
        jSons : ArrayOfString;
        i : Integer;
begin
        if Length(CorpNumList) = 0 then
        begin
                raise EClosedownException.Create(-99999999, '사업자번호가 입력되지 않았습니다');
                Exit;
        end;

        requestJson := '[';
        for i:=0 to Length(CorpNumList) -1 do
        begin
                requestJson := requestJson + '"' + CorpNumList[i] + '"';
                if (i + 1) < Length(CorpNumList) then requestJson := requestJson + ',';
        end;

        requestJson := requestJson +']';

        responseJson := httppost('/Check', requestJson);

        try
                jSons := ParseJsonList(responseJson);
                SetLength(result,Length(jSons));

                for i := 0 to Length(jSons)-1 do
                begin
                        result[i] := jsonToTCorpState(jSons[i]);
                end;

        except on E:Exception do
                raise EClosedownException.Create(-99999999, '결과처리 실패.[Malformed Json]');
        end;


end;

end.
