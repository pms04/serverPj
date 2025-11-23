<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.io.*, java.net.*, java.util.*, java.sql.*" %>
<%@ page import="com.google.gson.*" %>
<%@ page import="org.jsoup.Jsoup" %>
<%@ page import="org.jsoup.nodes.Document" %>
<%@ page import="org.jsoup.select.Elements" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%@ page import="java.util.Locale" %>
<%@ page import="java.util.TimeZone" %>
<%@ page import="java.util.Date" %>

<%!
    // 1. 네이버 API 및 DB 설정
    String clientId = "4dP6EbZsrEqoW0g4Ku1n"; 
    String clientSecret = "g57vu81ibQ";
    
    // DB 설정 (test_a / table_a / rootroot 적용)
    String dbUrl = "jdbc:mysql://localhost:3306/test_a?serverTimezone=UTC&useUnicode=true&characterEncoding=utf8";
    String dbUser = "root";
    String dbPass = "rootroot"; 
    
    // 4. [페이징 상수]
    final int DISPLAY_COUNT = 10; // 페이지당 보여줄 항목 수
    final int PAGE_BLOCK_SIZE = 5; // 페이지 블록 크기
    
    // 5. [최대 검색 건수 제한]
    final int MAX_TOTAL_RESULTS = 100;

    // 현재 시간과 비교하여 "N분 전" 또는 "N시간 전" 형식으로 변환하는 함수
    private String formatDateToRelativeTime(String naverDate) {
        if (naverDate == null || naverDate.isEmpty()) return "날짜 오류";
        
        try {
            // 네이버 API의 입력 형식 (RFC 822)
            SimpleDateFormat naverFormat = new SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss Z", Locale.ENGLISH);
            java.util.Date publishDate = naverFormat.parse(naverDate);
            java.util.Date currentDate = new java.util.Date(); // 현재 시간
            
            // 시간 차이 (밀리초)
            long diff = currentDate.getTime() - publishDate.getTime();
            
            long diffSeconds = diff / 1000;
            long diffMinutes = diff / (60 * 1000);
            long diffHours = diff / (60 * 60 * 1000);
            long diffDays = diff / (24 * 60 * 60 * 1000);

            if (diffDays > 30) {
                 // 한 달 이상 차이나면 YYYY.MM.DD 형식으로 출력
                 SimpleDateFormat monthFormat = new SimpleDateFormat("yyyy.MM.dd");
                 return monthFormat.format(publishDate);
            } else if (diffDays > 0) {
                // 1일 이상 차이
                return diffDays + "일 전";
            } else if (diffHours > 0) {
                // 1시간 이상 차이
                return diffHours + "시간 전";
            } else if (diffMinutes > 0) {
                // 1분 이상 차이
                return diffMinutes + "분 전";
            } else if (diffSeconds > 0) {
                // 1분 미만 차이
                return diffSeconds + "초 전";
            } else {
                return "방금 전";
            }
            
        } catch (java.text.ParseException e) {
            // 파싱 실패 시 원본 문자열 반환
            return naverDate; 
        }
    }
%>

<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>네이버 뉴스 검색 서비스 (세련됨 개선)</title>
    <style>
        /* ---------------------------------------------------- */
        /* 세련됨 개선 CSS */
        /* ---------------------------------------------------- */
        body { 
            font-family: 'Malgun Gothic', 'Nanum Gothic', sans-serif; 
            padding: 20px; 
            background-color: #f7f7f7; 
        }
        .search-box { 
            margin-bottom: 30px; 
            padding: 15px; 
            background: #f8f9fa; 
            border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05); 
        }
        .search-box form {
            display: flex; 
            gap: 10px;
        }
        .search-box input[type="text"] {
            flex-grow: 1; 
            padding: 10px 15px;
            border: 1px solid #cccccc;
            border-radius: 4px;
            font-size: 1em;
            transition: border-color 0.3s, box-shadow 0.3s;
        }
        .search-box input[type="text"]:focus {
            border-color: #3c82f6; 
            box-shadow: 0 0 0 3px rgba(60, 130, 246, 0.2);
            outline: none; 
        }
        button { 
            padding: 10px 20px; 
            background: #3c82f6; 
            color: white; 
            border: none; 
            cursor: pointer; 
            border-radius: 4px;
            font-weight: bold;
            transition: background 0.3s;
        }
        button:hover {
            background: #1c5fd1;
        }
        .error-box { 
            background-color: #fef2f2; 
            color: #ef4444; 
            padding: 15px; 
            border: 1px solid #fecaca; 
            border-radius: 5px; 
        }
        .highlight {
           color: #3c82f6; 
           font-weight: bold; 
           background-color: #eff6ff; 
           padding: 1px 3px;
           border-radius: 4px;
        }
        .card-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); 
            gap: 25px; 
            margin-top: 30px;
        }

        .news-card {
            background-color: white;
            border-radius: 12px; 
            box-shadow: 0 6px 16px rgba(0, 0, 0, 0.08); 
            overflow: hidden; 
            display: flex;
            flex-direction: column;
            transition: all 0.3s ease;
        }
        .news-card:hover {
            transform: translateY(-8px);
            box-shadow: 0 10px 20px rgba(0, 0, 0, 0.15);
        }

        .card-image-container {
            width: 100%;
            padding-top: 56.25%; 
            height: 0;
            position: relative;
            background-color: #e5e7eb; 
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
        }
        .card-image-container img {
            position: absolute;
            top: 0; left: 0;
            width: 100%;
            height: 100%;
            object-fit: cover; 
        }
        .card-image-container .no-image {
            color: #a0a0a0;
            font-size: 1.1em;
            position: absolute;
            top: 50%; left: 50%;
            transform: translate(-50%, -50%);
        }
        
        .card-content {
            padding: 20px; 
            flex-grow: 1; 
            display: flex;
            flex-direction: column;
        }
        .card-title {
            font-size: 1.15em;
            font-weight: 600; 
            margin-bottom: 10px;
        }
        .card-title a {
            color: #1f2937; 
            text-decoration: none;
            line-height: 1.4;
            display: block; 
        }
        .card-title a:hover {
            color: #3c82f6;
            text-decoration: underline;
        }
        .desc { 
            font-size: 0.9em; 
            color: #6b7280; 
            margin-bottom: 15px; 
            line-height: 1.6;
        }
        
        .card-date {
            font-size: 0.8em;
            color: #4b5563;      
            font-weight: normal; 
            margin-top: auto; 
        }

        .paging { 
            text-align: center; 
            margin-top: 40px; 
            font-size: 1.05em;
        }
        .paging a, .paging strong { 
            display: inline-block; 
            padding: 10px 18px; 
            margin: 0 4px; 
            border: 1px solid #e0e0e0; 
            border-radius: 6px; 
            text-decoration: none; 
            color: #4b5563; 
            background-color: white; 
            transition: all 0.2s;
        }
        .paging a:hover { 
            background-color: #f1f5f9; 
            border-color: #c3dafe; 
        }
        .paging strong { 
            background-color: #3c82f6; 
            color: white; 
            border-color: #3c82f6; 
            font-weight: bold; 
        }
    </style>
</head>
<body>

    <h2>📰 NEWs</h2> 
    <div class="search-box">
        <form method="GET">
            <input 
                type="text" 
                name="keyword" 
                id="keyword" 
                placeholder="검색어" 
                required 
                value="<%= (request.getParameter("keyword") != null ? request.getParameter("keyword") : "") %>">
            <button type="submit">🖱️</button>
        </form>
    </div>
    
 

    <%
        // 여기서 keyword 변수가 초기화됩니다.
        String keyword = request.getParameter("keyword");
        
        if (keyword != null && !keyword.trim().isEmpty()) {
            
            int currentPage = 1;
            try {
                currentPage = Integer.parseInt(request.getParameter("page"));
            } catch (Exception e) {
                currentPage = 1;
            }
            if (currentPage <= 0) currentPage = 1;

            int startNum = (currentPage - 1) * DISPLAY_COUNT + 1;
            
            if (startNum > MAX_TOTAL_RESULTS) {
                startNum = MAX_TOTAL_RESULTS - DISPLAY_COUNT + 1; 
                if (startNum < 1) startNum = 1;
            }
            
            // JDBC 드라이버 로드는 한 번만 시도 (Class.forName)
            boolean dbDriverLoaded = false;
            try {
                Class.forName("com.mysql.cj.jdbc.Driver");
                dbDriverLoaded = true;
            } catch (ClassNotFoundException e) {
                out.println("<div class='error-box'>DB 드라이버 로드 실패: com.mysql.cj.jdbc.Driver</div>");
            }

            
            // try-with-resources 구문을 사용하여 자원 자동 해제
            try (Connection conn = (dbDriverLoaded ? DriverManager.getConnection(dbUrl, dbUser, dbPass) : null);
                 PreparedStatement pstmt = (conn != null ? conn.prepareStatement("INSERT INTO table_a (title, origin_link, description, pub_date, search_keyword) VALUES (?, ?, ?, ?, ?)") : null)) {

                // API 호출
                String text = URLEncoder.encode(keyword, "UTF-8");
                String apiURL = "https://openapi.naver.com/v1/search/news.json?query=" + text + 
                                "&display=" + DISPLAY_COUNT + 
                                "&start=" + startNum;
                
                URL url = new URL(apiURL);
                HttpURLConnection con = (HttpURLConnection)url.openConnection();
                con.setRequestMethod("GET");
                con.setRequestProperty("X-Naver-Client-Id", clientId);
                con.setRequestProperty("X-Naver-Client-Secret", clientSecret);
                
                int responseCode = con.getResponseCode();
                
                try (BufferedReader br = new BufferedReader(new InputStreamReader(
                        (responseCode == 200 ? con.getInputStream() : con.getErrorStream()), "UTF-8"))) {
                    
                    StringBuffer responseBuffer = new StringBuffer();
                    String inputLine;
                    while ((inputLine = br.readLine()) != null) {
                        responseBuffer.append(inputLine);
                    }
                    
                    // Gson 파싱
                    JsonObject jsonObj = JsonParser.parseString(responseBuffer.toString()).getAsJsonObject();
                    
                    if (jsonObj.has("items")) {
                        
                        JsonArray items = jsonObj.getAsJsonArray("items");
                        
                        int actualTotal = jsonObj.get("total").getAsInt();
                        int totalResults = Math.min(actualTotal, MAX_TOTAL_RESULTS); 
                        
                        int totalPages = (int) Math.ceil((double) totalResults / DISPLAY_COUNT);
                        
    %>
                        
                        <div class="card-grid">
    <%
                        for (int i = 0; i < items.size(); i++) {
                            JsonObject item = items.get(i).getAsJsonObject();
                            
                            // 🟢 [수정] 네이버 <b> 태그를 .highlight span 태그로 대체하여 키워드 강조 (제목)
                            String titleHtml = item.get("title").getAsString().replaceAll("<b>", "<span class='highlight'>").replaceAll("</b>", "</span>");
                            
                            // 🟢 [수정] 네이버 <b> 태그를 .highlight span 태그로 대체하여 키워드 강조 (본문 요약)
                            String descriptionHtml = item.get("description").getAsString().replaceAll("<b>", "<span class='highlight'>").replaceAll("</b>", "</span>");

                            // DB 저장을 위해 HTML 태그를 제거한 순수 텍스트 제목 추출
                            String titleForDb = item.get("title").getAsString().replaceAll("<[^>]*>", "");

                            
                            String link = "";
                            if (item.has("originallink") && !item.get("originallink").isJsonNull()) {
                                 link = item.get("originallink").getAsString();
                            }
                            if (link.isEmpty() && item.has("link")) {
                                link = item.get("link").getAsString();
                            }
                            
                            // DB 저장을 위해 HTML 태그를 제거한 순수 텍스트 본문 추출
                            String descriptionForDb = item.get("description").getAsString().replaceAll("<[^>]*>", "");
                            String pubDate = item.get("pubDate").getAsString();
                            
                            String relativeTime = formatDateToRelativeTime(pubDate);
                            
                            // DB 저장 (pstmt가 준비된 경우에만 실행)
                            if (pstmt != null) {
                                try {
                                    pstmt.setString(1, titleForDb);
                                    pstmt.setString(2, link);
                                    pstmt.setString(3, descriptionForDb);
                                    pstmt.setString(4, pubDate);
                                    pstmt.setString(5, keyword);
                                    pstmt.executeUpdate();
                                } catch (SQLException e) {
                                    // DB 저장 중 오류 발생 시 출력 대신 로깅 처리 권장
                                }
                            }
    %>
                            <div class="news-card">
                                <div class="card-image-container" data-link="<%= link %>">
                                    <span class="no-image">로딩 중...</span>
                                </div>
                                <div class="card-content">
                                    <div class="card-title"><a href="<%= link %>" target="_blank"><%= titleHtml %></a></div>
                                    <div class="desc"><%= descriptionHtml %></div>
                                    <div class="card-date"><%= relativeTime %></div>
                                </div>
                            </div>
    <%
                        } // end for
    %>
                        </div> <%-- end card-grid --%>
                        
                        <%-- 페이징 영역 출력 --%>
                        <div class="paging">
                        <%
                            int startPage = ((currentPage - 1) / PAGE_BLOCK_SIZE) * PAGE_BLOCK_SIZE + 1;
                            int endPage = startPage + PAGE_BLOCK_SIZE - 1;
                            
                            if (endPage > totalPages) {
                                endPage = totalPages;
                            }

                            String linkFormat = "?keyword=" + URLEncoder.encode(keyword, "UTF-8") + "&page=";
                            
                            // 이전 블록
                            if (startPage > 1) {
                                int prevBlockPage = startPage - 1;
                                out.println("<a href='" + linkFormat + prevBlockPage + "'>&laquo;</a>");
                            }
                            
                            // 페이지 번호 출력
                            for (int p = startPage; p <= endPage; p++) {
                                
                                if ((p - 1) * DISPLAY_COUNT + 1 > MAX_TOTAL_RESULTS) break; 
                                
                                if (p == currentPage) {
                                    out.println("<strong>" + p + "</strong>");
                                } else {
                                    out.println("<a href='" + linkFormat + p + "'>" + p + "</a>");
                                }
                            }
                            
                            // 다음 블록
                            if (endPage < totalPages && endPage * DISPLAY_COUNT < MAX_TOTAL_RESULTS) {
                                int nextBlockPage = endPage + 1;
                                out.println("<a href='" + linkFormat + nextBlockPage + "'>&raquo;</a>");
                            }
                        %>
                        </div>
    <%
                    } else {
                        // API 에러 처리
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
                        </div>
    <%
                    } // end else (API error handling)
                } // end try with br (BufferedReader)
            } catch (Exception e) {
                out.println("<div class='error-box'>시스템 에러 발생: " + e.getMessage() + "</div>");
            } // conn, pstmt는 try-with-resources에 의해 자동 close됨

        } // end if (keyword != null)
    %>

<script>
    // **비동기 썸네일 로딩 JavaScript**
    document.addEventListener('DOMContentLoaded', function() {
        const containers = document.querySelectorAll('.card-image-container');
        
        containers.forEach(container => {
            const newsLink = container.getAttribute('data-link');
            if (newsLink) {
                // 주의: 'loadImage.jsp' 파일이 서버에 존재하고 CORS 문제를 해결할 수 있도록 구성되어 있어야 합니다.
                fetch('loadImage.jsp?url=' + encodeURIComponent(newsLink))
                    .then(response => response.text())
                    .then(thumbnailUrl => {
                        container.innerHTML = ''; 
                        
                        if (thumbnailUrl && thumbnailUrl.trim() !== 'null') {
                            const img = document.createElement('img');
                            img.src = thumbnailUrl.trim();
                            img.alt = '기사 썸네일';
                            container.appendChild(img);
                        } else {
                            const span = document.createElement('span');
                            span.className = 'no-image';
                            span.textContent = '[No Image]';
                            container.appendChild(span);
                        }
                    })
                    .catch(error => {
                        container.innerHTML = '<span class="no-image" style="color: #d9534f;">[Fail]</span>';
                    });
            } else {
                container.innerHTML = '<span class="no-image">[No Link]</span>';
            }
        });
    });
</script>

</body>
</html>