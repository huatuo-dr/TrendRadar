import requests
import json
from typing import Tuple, Optional

def fetch_csdn_data(id_value: str, alias: str) -> Tuple[Optional[str], str, str]:
    """获取CSDN热榜数据"""
    url = "https://blog.csdn.net/phoenix/web/blog/hot-rank?page=0&pageSize=25"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Referer": "https://blog.csdn.net/rank/list",
    }
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()
        
        if data.get("code") != 200:
            raise ValueError(f"CSDN API Error: {data.get('message')}")
            
        items = []
        for item in data.get("data", []):
            items.append({
                "title": item.get("articleTitle"),
                "url": item.get("articleDetailUrl"),
                "mobileUrl": item.get("articleDetailUrl")
            })
            
        result = {
            "status": "success",
            "items": items
        }
        
        print(f"获取 {id_value} 成功（最新数据）")
        return json.dumps(result, ensure_ascii=False), id_value, alias
        
    except Exception as e:
        print(f"请求 {id_value} 失败: {e}")
        return None, id_value, alias
