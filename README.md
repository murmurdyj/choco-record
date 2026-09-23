# 治療生活紀錄｜安裝說明

- `index.html`：App 本體（手機優先，單一檔案）
- `schema.sql`：Supabase 資料表、權限（RLS）、即時同步設定
- `README.md`：本說明

沒有填 Supabase 連線資訊時，`index.html` 會自動進入「示範模式」，顯示假資料，方便先看介面。

## 1. 建立 Supabase 專案

1. 到 supabase.com 建立新專案。
2. 左側 **SQL Editor** → 新增查詢 → 貼上 `schema.sql` 全部內容 → Run。
3. **Authentication → Sign In / Providers → Email** 保持開啟。
   - 不想收確認信的話，可以關閉「Confirm email」。
4. **Project Settings → API**（或 API Keys）複製 Project URL 和 anon key（新專案可能叫 publishable key）。
   **不要**把 service_role／secret key 放進 index.html。

## 2. 填入連線資訊

打開 `index.html`，找到最上方的 `CONFIG`，填入 URL 與 key，存檔。

## 3. 放上網路

Netlify Drop（把資料夾拖進去）、Vercel、Cloudflare Pages、GitHub Pages 都可以，需要是 https 網址。

## 4. 兩支手機登入

1. 第一支手機：打開網址 →「第一次使用」→ 輸入 Email 和密碼建立帳號 → 登入。
2. 第二支手機：打開網址 →「登入」→ 輸入**同一組** Email 和密碼。
3. 每支手機第一次進入時選「這支手機是誰在用」，之後紀錄會顯示是誰寫的。
4. 兩支手機都用 Safari／Chrome 的「加入主畫面」，之後就像 App 一樣開啟，不用再登入。

第一次登入會自動建立共享空間，並放入一筆 2026-09-23「施打柳培林」示範治療紀錄，可以修改或刪除。

## 如果打開後資料看起來不見了

先不要慌，通常資料還在資料庫裡。App 抓不到資料時，頂端會出現紅色提示，並保留畫面上最後一次讀到的內容，不會顯示成一片空白。

最常見的原因是 **Supabase 免費專案一段時間沒使用會被自動暫停**：

1. 登入 Supabase 後台，看專案是否顯示 Paused。
2. 按 Restore，等幾分鐘恢復後重新整理 App。

暫停規則與可恢復期限以 Supabase 官方文件「Project Pausing」為準，規則可能變動，請定期確認。

## 備份

設定（右上角 ⚙︎）→「匯出全部資料」會下載一個 JSON 檔。建議每個月存一次，放到雲端硬碟。

## 與原始規格的差異

- 兩人共用一個帳號；`profiles` 表與邀請碼已移除，改用 `care_spaces.people` 存名字，每筆紀錄存 `updated_by_name`／`created_by_name`。
- `daily_habits` 多一個 `care_space_id` 欄位，方便權限判斷與同步。
- `daily_records` 多一個 `red_flags` 欄位：勾選「單側下腹痛」後可再點「突然、劇烈／噁心嘔吐／冒冷汗／站不住」，符合條件時畫面顯示「請儘快就醫。」
- `shared_notes` 改成可多筆，最多 3 則（資料庫也有檢查）。
- 底部選單改為 5 頁：今日、趨勢、紀錄、治療、生活。
- 生活打卡勾選後自動同步（身體紀錄仍需按按鈕才儲存）。
