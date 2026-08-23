import requests, json, base64

class GithubManager:
    def __init__(self, cfg):
        self.cfg = cfg

    def _url(self, path):
        return f"https://api.github.com/repos/{self.cfg['GITHUB_OWNER']}/{self.cfg['GITHUB_REPO']}/contents/{path}"

    def get_json(self, path):
        h={"Authorization":f"Bearer {self.cfg['GITHUB_TOKEN']}"}
        r=requests.get(self._url(path),headers=h,params={"ref":self.cfg["GITHUB_BRANCH"]})
        r.raise_for_status()
        j=r.json()
        return json.loads(base64.b64decode(j["content"]).decode()), j["sha"]

    def get_text(self, path):
        h={"Authorization":f"Bearer {self.cfg['GITHUB_TOKEN']}"}
        r=requests.get(self._url(path),headers=h,params={"ref":self.cfg["GITHUB_BRANCH"]})
        r.raise_for_status()
        j=r.json()
        return base64.b64decode(j["content"]).decode()

    def save_json(self,path,data,sha,msg="Update"):
        h={"Authorization":f"Bearer {self.cfg['GITHUB_TOKEN']}"}
        payload={
            "message":msg,
            "content":base64.b64encode(json.dumps(data,ensure_ascii=False,indent=2).encode()).decode(),
            "sha":sha,
            "branch":self.cfg["GITHUB_BRANCH"]
        }
        r=requests.put(self._url(path),headers=h,json=payload)
        r.raise_for_status()