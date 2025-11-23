<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.io.*, java.net.*, java.util.*, java.sql.*" %>
<%@ page import="com.google.gson.*" %>

<%!
    String clientId = "CJT5P3q5HGD72UjrspS_"; 
    String clientSecret = "VYS4ZeuCxa";

    String dbUrl = "jdbc:mysql://localhost:3306/test_a?serverTimezone=UTC&useUnicode=true&characterEncoding=utf8";
    String dbUser = "root";
    String dbPass = "rootroot"; 
%>

<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Naver News Search</title>

<style>
    body {
        background-color: #0d0d0d;
        color: #e6e6e6;
        font-family: 'Malgun Gothic', sans-serif;
        padding: 20px;
    }
    h2 {
        color: #d4af37;  
        text-shadow: 0 0 5px #d4af37;
    }
    .search-box {
        margin-bottom: 20px;
        padding: 20px;
        background: #1a1a1a;
        border: 1px solid #333;
        border-radius: 8px;
    }
    .search-box label {
        color: #d4af37;
        font-size: 1.1em;
    }
    input[type=text] {
        width: 250px;
        padding: 8px;
        border: 1px solid #555;
        background: #111;
        color: #e6e6e6;
        border-radius: 4px;
    }
    button {
        padding: 8px 20px;
        background: #d4af37;
        color: black;
        border: none;
        border-radius: 4px;
        cursor: pointer;
        font-weight: bold;
    }
    button:hover {
        background: #b8922b;
    }
    table {
        width: 100%;
        border-collapse: collapse;
        margin-top: 25px;
        background: #1a1a1a;
        border: 1px solid #333;
    }
    th {
        background: #d4af37;
        color: black;
        padding: 10px;
        text-align: left;
    }
    td {
        border: 1px solid #333;
        padding: 10px;
        color: #ccc;
    }
    tr:nth-child(even) {
        background-color: #141414;
    }
    a {
        color: #ffdd75;
        text-decoration: none;
    }
    a:hover {
        text-decoration: underline;
    }
    .desc {
        color: #bbbbbb;
    }
    .error-box {
        background: #330000;
        border: 1px solid #660000;
        color: #ff6666;
        padding: 20px;
        border-radius: 8px;
    }
</style>

</head>
<body>

<h2>📰 Naver 뉴스 검색 </h2>

<div class="search-box">
    <form method="GET">
        <label>검색어:</label>
        <input type="text" name="keyword" placeholder="예: 인공지능" required>
        <button type="submit">검색</button>
    </form>
</div>

<%
    String keyword = request.getParameter("keyword");

    if(keyword != null && !keyword.trim().isEmpty()) {

        Connection conn = null;
        PreparedStatement pstmt = null;

        try {
            String text = URLEncoder.encode(keyword, "UTF-8");
            String apiURL = "https://openapi.naver.com/v1/search/news.json?query=" + text + "&display=100";

            URL url = new URL(apiURL);
            HttpURLConnection con = (HttpURLConnection)url.openConnection();
            con.setRequestMethod("GET");
            con.setRequestProperty("X-Naver-Client-Id", clientId);
            con.setRequestProperty("X-Naver-Client-Secret", clientSecret);

            BufferedReader br;
            if(con.getResponseCode() == 200) {
                br = new BufferedReader(new InputStreamReader(con.getInputStream(), "UTF-8"));
            } else {
                br = new BufferedReader(new InputStreamReader(con.getErrorStream(), "UTF-8"));
            }

            StringBuffer sb = new StringBuffer();
            String line;
            while((line = br.readLine()) != null) sb.append(line);
            br.close();

            JsonObject json = JsonParser.parseString(sb.toString()).getAsJsonObject();

            if(json.has("items")) {

                JsonArray items = json.getAsJsonArray("items");

                Class.forName("com.mysql.cj.jdbc.Driver");
                conn = DriverManager.getConnection(dbUrl, dbUser, dbPass);

                String sql = "INSERT INTO table_a (title, origin_link, description, pub_date, search_keyword) VALUES (?, ?, ?, ?, ?)";
                pstmt = conn.prepareStatement(sql);

%>
<table>
    <tr>
        <th>No</th>
        <th>제목</th>
        <th>요약 내용</th>
        <th>작성일</th>
    </tr>

<%
                for(int i = 0; i < items.size(); i++) {
                    JsonObject item = items.get(i).getAsJsonObject();

                    String title = item.get("title").getAsString().replaceAll("<[^>]*>", "");
                    String link = item.get("originallink").isJsonNull() ? item.get("link").getAsString() : item.get("originallink").getAsString();
                    String description = item.get("description").getAsString().replaceAll("<[^>]*>", "");
                    String pubDate = item.get("pubDate").getAsString();

                    String shortDesc = description.length() > 50 ? description.substring(0,50)+"..." : description;

                    pstmt.setString(1, title);
                    pstmt.setString(2, link);
                    pstmt.setString(3, description);
                    pstmt.setString(4, pubDate);
                    pstmt.setString(5, keyword);
                    pstmt.executeUpdate();
%>

<tr>
    <td><%= i+1 %></td>
    <td><a href="<%= link %>" target="_blank"><%= title %></a></td>
    <td class="desc"><%= shortDesc %></td>
    <td><%= pubDate %></td>
</tr>

<%
                }
%>
</table>

<%
            } else {
%>
<div class="error-box">
    API 에러 발생: items 없음  
</div>
<%
            }

        } catch(Exception e) {
%>
<div class="error-box">
    오류 발생: <%= e.getMessage() %>
</div>
<%
        } finally {
            if(pstmt!=null) try{ pstmt.close(); } catch(Exception ex){}
            if(conn!=null) try{ conn.close(); } catch(Exception ex){}
        }
    }
%>

</body>
</html>