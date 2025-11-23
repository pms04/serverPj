<%@ page language="java" contentType="text/plain; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.io.*" %>
<%@ page import="java.net.*" %>
<%@ page import="org.jsoup.Jsoup" %>
<%@ page import="org.jsoup.nodes.Document" %>
<%@ page import="org.jsoup.select.Elements" %>
<%@ page import="org.jsoup.nodes.Element" %>

<%
    // 응답 Content-Type을 'text/plain'으로 설정하여 순수한 썸네일 URL 문자열만 반환합니다.
    response.setContentType("text/plain; charset=UTF-8");
    
    // 1. 요청 파라미터에서 기사 URL 가져오기
    String newsUrl = request.getParameter("url");
    
    // 유효성 검사
    if (newsUrl == null || newsUrl.isEmpty()) {
        out.print("null"); // URL이 없으면 'null' 문자열 반환
        return;
    }

    String thumbnailUrl = null;
    
    try {
        // 2. JSoup을 사용하여 해당 URL의 HTML 문서를 가져옵니다.
        Document doc = Jsoup.connect(newsUrl)
                            .timeout(5000) // 5초 타임아웃
                            .userAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36") // User-Agent 설정
                            .get();
        
        // 3. Open Graph (og:image) 메타 태그 검색 (우선 순위 1)
        Elements ogImage = doc.select("meta[property=og:image]");
        if (!ogImage.isEmpty()) {
            thumbnailUrl = ogImage.attr("content");
        } 
        
        // 4. twitter:image 태그 검색 (우선 순위 2)
        if (thumbnailUrl == null || thumbnailUrl.isEmpty()) {
            Elements twitterImage = doc.select("meta[name=twitter:image]");
            if (!twitterImage.isEmpty()) {
                thumbnailUrl = twitterImage.attr("content");
            }
        }
        
        // 5. 본문 내의 첫 번째 큰 이미지 검색 (우선 순위 3 - 최후의 수단)
        if (thumbnailUrl == null || thumbnailUrl.isEmpty()) {
            Elements bodyImages = doc.select("article img, div[class*=article-content] img, figure img");
            if (!bodyImages.isEmpty()) {
                Element firstImage = bodyImages.first();
                String src = firstImage.attr("src");
                
                if (firstImage.hasAttr("data-src")) {
                    src = firstImage.attr("data-src");
                }
                
                if (src != null && !src.isEmpty()) {
                    thumbnailUrl = firstImage.absUrl("src"); 
                }
            }
        }
        
    } catch (IOException e) {
        // 네트워크 연결 및 HTML 문서 가져오기 실패
        thumbnailUrl = null; 
    } catch (Exception e) {
        // 기타 예외
        thumbnailUrl = null;
    }
    
    // 6. 결과 출력
    if (thumbnailUrl != null && !thumbnailUrl.isEmpty()) {
        out.print(thumbnailUrl.trim().replace("&amp;", "&"));
    } else {
        out.print("null");
    }
%>