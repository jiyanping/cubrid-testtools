<%@ page contentType="text/html;charset=utf-8"%>
<%@ page import="com.navercorp.cubridqa.cqt.webconsole.WebModel" %>
<%

WebModel web = new WebModel((String)application.getAttribute("DAILYQA_ROOT"));
String p=(String)request.getParameter("p");

%>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title>
CQT Web Console - Browse
</title>
</head>
<body>
<%=web.showTestCase(p)%>
<br>
<br>
</body>
</html>