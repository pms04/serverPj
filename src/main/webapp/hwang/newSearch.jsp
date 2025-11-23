<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.io.*, java.net.*, java.util.*, java.sql.*" %>
<%@ page import="com.google.gson.*" %> <%-- Gson 라이브러리 필수 --%>

<%!
    // 1. 네이버 API 및 DB 설정
    // 주의: 실제 서비스 시 키 값은 별도 파일로 분리하는 것이 보안상 좋습니다.
    String clientId = "4dP6EbZsrEqoW0g4Ku1n"; 
    String clientSecret = "g57vu81ibQ";
    
    // DB 설정 (test_a / table_a / rootroot 적용)
    String dbUrl = "jdbc:mysql://localhost:3306/test_a?serverTimezone=UTC&useUnicode=true&characterEncoding=utf8";
    String dbUser = "root";
    String dbPass = "rootroot"; 
%>

<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>네이버 뉴스 검색 서비스</title>
    <style>
        body { font-family: 'Malgun Gothic', sans-serif; padding: 20px; }
        .search-box { margin-bottom: 20px; padding: 15px; background: #e3f2fd; border-radius: 5px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #1976D2; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .desc { font-size: 0.9em; color: #555; }
        .error-box { background-color: #ffebee; color: #c62828; padding: 15px; border: 1px solid #ef9a9a; border-radius: 5px; }
        button { padding: 5px 15px; background: #1565C0; color: white; border: none; cursor: pointer; }
    </style>
</head>
<body>

    <h2>📰 Naver 뉴스 검색 & DB 저장 (최종 수정판)</h2>

    <div class="search-box">
        <form method="GET">
            <label for="keyword">검색어:</label>
            <input type="text" name="keyword" id="keyword" placeholder="예: 인공지능" required>
            <button type="submit">검색</button>
        </form>
    </div>

    <%
        String keyword = request.getParameter("keyword");
        
        if (keyword != null && !keyword.trim().isEmpty()) {
            
            Connection conn = null;
            PreparedStatement pstmt = null;
            
            try {
                // 2. API 호출
                String text = URLEncoder.encode(keyword, "UTF-8");
                String apiURL = "https://openapi.naver.com/v1/search/news.json?query=" + text + "&display=100";
                
                URL url = new URL(apiURL);
                HttpURLConnection con = (HttpURLConnection)url.openConnection();
                con.setRequestMethod("GET");
                con.setRequestProperty("X-Naver-Client-Id", clientId);
                con.setRequestProperty("X-Naver-Client-Secret", clientSecret);
                
                int responseCode = con.getResponseCode();
                BufferedReader br;
                if(responseCode == 200) {
                    br = new BufferedReader(new InputStreamReader(con.getInputStream(), "UTF-8"));
                } else { 
                    br = new BufferedReader(new InputStreamReader(con.getErrorStream(), "UTF-8"));
                }
                
                StringBuffer responseBuffer = new StringBuffer();
                String inputLine;
                while ((inputLine = br.readLine()) != null) {
                    responseBuffer.append(inputLine);
                }
                br.close();
                
                // 디버깅용 출력 (실제 서비스 시에는 주석 처리 권장)
                //out.println("<p style='font-size:12px; color:#888;'>API 응답 원본: " + responseBuffer.toString() + "</p>");
                
                // ---------------------------------------------------------
                // 3. Gson 파싱 및 에러 처리 (핵심 수정 부분)
                // ---------------------------------------------------------
                
                JsonObject jsonObj = JsonParser.parseString(responseBuffer.toString()).getAsJsonObject();
                
                // [중요] "items" 키가 있는지 먼저 확인합니다.
                if (jsonObj.has("items")) {
                    
                    JsonArray items = jsonObj.getAsJsonArray("items");
                    
                    // DB 연결 (API 호출 성공 시에만 연결)
                    Class.forName("com.mysql.cj.jdbc.Driver");
                    conn = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                    
                    String sql = "INSERT INTO table_a (title, origin_link, description, pub_date, search_keyword) VALUES (?, ?, ?, ?, ?)";
                    pstmt = conn.prepareStatement(sql);

    %>
                    <h3>'<%= keyword %>' 검색 결과 (총 <%= items.size() %>건 처리)</h3>
                    <table>
                        <thead>
                            <tr>
                                <th width="5%">No</th>
                                <th width="30%">제목</th>
                                <th width="50%">내용 (요약)</th>
                                <th width="15%">작성일</th>
                            </tr>
                        </thead>
                        <tbody>
    <%
                    for (int i = 0; i < items.size(); i++) {
                        JsonObject item = items.get(i).getAsJsonObject();
                        
                        String title = item.get("title").getAsString().replaceAll("<[^>]*>", "");
                        
                        String link = "";
                        if (item.has("originallink") && !item.get("originallink").isJsonNull()) {
                             link = item.get("originallink").getAsString();
                        }
                        if (link.isEmpty()) {
                            link = item.get("link").getAsString();
                        }
                        
                        String description = item.get("description").getAsString().replaceAll("<[^>]*>", "");
                        String pubDate = item.get("pubDate").getAsString();

                        String shortDesc = description;
                        if (shortDesc.length() > 50) {
                            shortDesc = shortDesc.substring(0, 50) + "...";
                        }

                        // DB 저장
                        pstmt.setString(1, title);
                        pstmt.setString(2, link);
                        pstmt.setString(3, description);
                        pstmt.setString(4, pubDate);
                        pstmt.setString(5, keyword);
                        pstmt.executeUpdate();
    %>
                            <tr>
                                <td><%= i + 1 %></td>
                                <td><a href="<%= link %>" target="_blank"><%= title %></a></td>
                                <td class="desc"><%= shortDesc %></td>
                                <td><%= pubDate %></td>
                            </tr>
    <%
                    } // end for
    %>
                        </tbody>
                    </table>
    <%
                } else {
                    // [중요] items가 없으면 에러 메시지를 출력합니다.
                    String errMsg = "알 수 없는 오류";
                    String errCode = "None";
                    
                    if (jsonObj.has("errorMessage")) {
                        errMsg = jsonObj.get("errorMessage").getAsString();
                    }
                    if (jsonObj.has("errorCode")) {
                        errCode = jsonObj.get("errorCode").getAsString();
                    }
    %>
                    <div class="error-box">
                        <h3>⚠️ API 호출 오류 발생</h3>
                        <p><strong>에러 코드:</strong> <%= errCode %></p>
                        <p><strong>에러 메시지:</strong> <%= errMsg %></p>
                        <p>Client ID와 Secret이 정확한지, 공백이 없는지 확인해주세요.</p>
                    </div>
    <%
                } // end else (API error handling)

            } catch (Exception e) {
                out.println("<div class='error-box'>시스템 에러 발생: " + e.getMessage() + "</div>");
                e.printStackTrace();
            } finally {
                if (pstmt != null) try { pstmt.close(); } catch(Exception e) {}
                if (conn != null) try { conn.close(); } catch(Exception e) {}
            }
        }
    %>
</body>
</html>