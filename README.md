# PathSlayer

สคริปต์ช่วยเล่นสำหรับ executor: Auto-Quest, Auto-Money-Farm (วนฆ่าบอสเก็บ Coin Pouch แล้วขายให้ Ginzo), Auto-Attack, Kill Aura, Auto Skill, Auto-Dodge / Parry, Auto-Chest, Get Weapons (ซื้อ ฟาร์ม หรือตีอาวุธและของสวมใส่ให้อัตโนมัติ), Webhook Discord (แท็บ Settings)

## วิธีใช้

วางบรรทัดนี้ใน executor แล้วรัน

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/nawapolmahamahawong-code/PathSlayer/main/src/PathSlayerUI.lua"))()
```

executor ต้องรองรับ `getconnections`, `fireproximityprompt`, `gethui`, `readfile` / `writefile` / `isfile` / `makefolder`, `request` (สำหรับ Webhook)
