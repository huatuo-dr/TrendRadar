import requests
import re
from typing import Tuple, Optional
import json

def fetch_oshwhub_data(id_value: str, alias: str) -> Tuple[Optional[str], str, str]:
    """获取嘉立创开源广场热门项目"""
    url = "https://oshwhub.com/explore"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    }
    
    try:
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        html_content = response.text
        
        # 使用正则提取项目链接和标题
        # 匹配模式: <a href="/username/project" ... title="Project Title">...</a>
        # 或者从 markdown 转换后的文本中提取: [Title](https://oshwhub.com/username/project)
        
        # 由于我们直接获取的是HTML，我们需要匹配 HTML 标签
        # 典型的项目卡片结构可能包含 href="/username/project-slug" 和 title="Project Name"
        
        # 尝试匹配项目链接
        # 假设链接格式为 /username/project-slug (非 /explore, /activities 等)
        # 并且通常会有 title 属性或者在标签内部有文本
        
        items = []
        seen_urls = set()
        
        # 尝试从 Next.js 数据中提取 (处理转义引号)
        # 数据格式: \"path\":\"username/project-slug\",...,\"name\":\"Project Name\"
        matches = list(re.finditer(r'\\"path\\":\\"([^\\"]+)\\".*?\\"name\\":\\"([^\\"]+)\\"', html_content))
        
        # 如果没找到，尝试不转义的 (以防万一)
        if not matches:
             matches = list(re.finditer(r'"path":"([^"]+)".*?"name":"([^"]+)"', html_content))
             
        for match in matches:
            path = match.group(1)
            # 直接使用提取的标题，不需要额外的编码转换
            # HTML 中的 JSON 字符串已经是正确的 UTF-8 编码
            title = match.group(2)
            
            # 排除非项目路径
            if not path or path.startswith('/') or 'activities' in path:
                continue
                
            full_url = f"https://oshwhub.com/{path}"
            
            if full_url not in seen_urls:
                items.append({
                    "title": title,
                    "url": full_url,
                    "mobileUrl": full_url
                })
                seen_urls.add(full_url)
            
            if len(items) >= 25:
                break
                
        # 如果上面的正则没抓到，尝试旧的 HTML 链接匹配作为备选
        if not items:
            matches = re.finditer(r'href="(/[^/"]+/[^/"]+)"[^>]*>([^<]+)</a>', html_content)
            for match in matches:
                link = match.group(1)
                title = match.group(2).strip()
                # ... (保留旧逻辑作为 fallback)
                title = re.sub(r'<[^>]+>', '', title).strip()
                if not link or not title: continue
                full_url = f"https://oshwhub.com{link}"
                
                exclude_paths = ['/explore', '/activities', '/market', '/article', '/education', '/fantasy', '/project/choose', '/sign_in']
                is_valid = True
                for exclude in exclude_paths:
                    if exclude in full_url:
                        is_valid = False
                        break
                
                if is_valid and full_url not in seen_urls:
                    items.append({
                        "title": title,
                        "url": full_url,
                        "mobileUrl": full_url
                    })
                    seen_urls.add(full_url)
                if len(items) >= 25:
                    break

        result = {
            "status": "success",
            "items": items
        }
        
        print(f"获取 {id_value} 成功（最新数据）- 抓取到 {len(items)} 条")
        return json.dumps(result, ensure_ascii=False), id_value, alias
        
    except Exception as e:
        print(f"请求 {id_value} 失败: {e}")
        return None, id_value, alias
