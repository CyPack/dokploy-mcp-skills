# Atomic CRM — Playwright/Chrome DevTools Browser Test Rehberi

> Deploy sonrasi browser uzerinden end-to-end dogrulama.
> Chrome DevTools MCP (chrome-devtools) veya Playwright MCP kullanilabilir.
> Bu rehber 2026-04-13 deployment'indan ogrenilen adimlari ve tuzaklari icerir.

---

## On Kosullar

| Gerekli | Dogrulama |
|---------|-----------|
| Atomic CRM container UP | `docker ps \| grep atomic` → `0.0.0.0:3015->80/tcp` |
| Supabase API erisimi | `curl -s -w "%{http_code}" http://supabase-...-traefik.me/rest/v1/` → `401` |
| Traefik → Supabase network | `docker network connect supabase-supabase-0qdhd3 dokploy-traefik 2>/dev/null` |
| `/etc/hosts` dogru IP | `grep supabase /etc/hosts` → `192.168.2.13` (127.0.0.1 DEGIL!) |
| Email autoconfirm aktif | `docker exec supabase-...-auth env \| grep GOTRUE_MAILER_AUTOCONFIRM` → `true` |
| Chrome/Chromium acik | Chrome DevTools MCP bagli olmali |

---

## Test 1: Sayfa Yuklenmesi

### Amac
Frontend container'dan nginx dogru dosyalari servis ediyor mu, SPA routing calisiyor mu?

### Adimlar (Chrome DevTools MCP)

```
1. navigate_page(type="url", url="http://localhost:3015")
   → Beklenen: /#/sign-up veya /#/login'e yonlendirilmeli

2. take_screenshot()
   → Beklenen: "Welcome to Atomic CRM" veya login formu gorunmeli

3. list_network_requests(resourceTypes=["fetch","xhr"])
   → Beklenen: init_state → 200 (Supabase API calisiyor)
   → HATA: ERR_CONNECTION_REFUSED ise → /etc/hosts + Traefik network kontrol et
   → HATA: 504 ise → docker network connect fix'i gerekli
```

### Beklenen Sonuc
- HTTP 200, sayfa render ediliyor
- Supabase `init_state` endpoint'i 200 donuyor
- Console'da critical JS hatasi yok

---

## Test 2: Ilk Kullanici Signup (Admin)

### Amac
Supabase Auth signup calisiyor mu, `handle_new_user` trigger'i sales kaydini olusturuyor mu?

### Adimlar

```
1. navigate_page(type="url", url="http://localhost:3015")
   → /#/sign-up'a yonlenmeli

2. take_snapshot()
   → uid'leri al: First name, Last name, Email, Password, Create account

3. fill(uid=<first_name>, value="Test")
   fill(uid=<last_name>, value="User")
   fill(uid=<email>, value="test@example.com")
   fill(uid=<password>, value="SecurePassword123!")

4. click(uid=<create_account_button>)
   → Buton "Creating..." olur, sonra redirect

5. sleep 5 saniye

6. take_screenshot()
   → Beklenen: Dashboard sayfasi, "What's next?" onboarding
```

### Olasi Hatalar

| Hata | Network Tab | Neden | Fix |
|------|------------|-------|-----|
| Buton "Creating..." kalip geri donuyor | `POST /auth/v1/signup → 500` | SMTP yok, email confirmation fail | `ENABLE_EMAIL_AUTOCONFIRM=true` fix'i uygula (golden-path.md Troubleshooting) |
| Sayfa hic degismiyor | `ERR_CONNECTION_REFUSED` | Supabase API erisimi yok | `/etc/hosts` IP + Traefik network fix'i |
| "User already registered" | `POST /auth/v1/signup → 422` | Ayni email ile daha once kayit yapilmis | Farkli email dene |
| Dashboard acildi ama bos | `GET /rest/v1/* → 401` | ANON_KEY yanlis | Image'i dogru key ile rebuild et |

### Dogrulama (DB tarafinda)

```bash
# Kullanici auth.users'da olusturulmus mu?
docker exec -i supabase-supabase-0qdhd3-supabase-db psql -U postgres -d postgres -c \
  "SELECT id, email, created_at FROM auth.users ORDER BY created_at DESC LIMIT 1;"

# handle_new_user trigger calismis mi? (sales tablosuna kayit dusmeli)
docker exec -i supabase-supabase-0qdhd3-supabase-db psql -U postgres -d postgres -c \
  "SELECT id, first_name, last_name, email, administrator FROM public.sales ORDER BY id DESC LIMIT 1;"
# → administrator = TRUE (ilk kullanici admin olur)
```

---

## Test 3: Contact Olusturma (CRUD)

### Amac
Temel CRM fonksiyonelligi calisiyor mu — contact oluşturma, kaydetme, goruntuleme?

### Adimlar

```
1. take_snapshot() → Dashboard'da "New Contact" link'ini bul
2. click(uid=<new_contact_link>)
   → /contacts/create sayfasina gitmeli

3. take_snapshot() → Form field uid'lerini al
4. fill(uid=<first_name>, value="Test")
   fill(uid=<last_name>, value="Contact")
   fill(uid=<title>, value="Software Engineer")
   fill(uid=<email>, value="test@example.com")

5. take_snapshot() → "Account manager" otomatik dolmus mu?
   → Beklenen: Signup yapan kullanicinin adi gorunmeli

6. click(uid=<save_button>)

7. sleep 3 saniye

8. take_screenshot()
   → Beklenen: Contact detay sayfasi
   → Avatar (TC), isim, title, email, "Added on [tarih]"
   → "Edit contact", "Add tag", "Add task" butonlari
```

### Dogrulama (DB)

```bash
docker exec -i supabase-supabase-0qdhd3-supabase-db psql -U postgres -d postgres -c \
  "SELECT id, first_name, last_name, title FROM public.contacts ORDER BY id DESC LIMIT 1;"
```

---

## Test 4: Navigasyon ve Sayfa Butunlugu

### Amac
Tum ana sayfalar hatasiz yukleniyor mu?

### Adimlar

```
# Her sayfa icin: navigate → screenshot → console check
sayfalar = [
  ("Dashboard", "http://localhost:3015/#/"),
  ("Contacts", "http://localhost:3015/#/contacts"),
  ("Companies", "http://localhost:3015/#/companies"),
  ("Deals", "http://localhost:3015/#/deals"),
]

Her sayfa icin:
1. navigate_page(type="url", url=sayfa_url)
2. sleep 2
3. take_screenshot()
   → Sayfa dogru render ediliyor mu?
4. list_console_messages()
   → Critical JS hatasi var mi? (401/403 harici — bunlar auth ile normal)
5. list_network_requests(resourceTypes=["fetch"])
   → Tum API istekleri 200 veya 401 (auth) donmeli
   → 500 veya ERR_ → sorun var
```

### Beklenen Sonuclar

| Sayfa | Beklenen Icerik |
|-------|----------------|
| Dashboard | "What's next?" onboarding card, navigasyon bar |
| Contacts | Contact listesi veya "No contacts found" + "New Contact" butonu |
| Companies | Company listesi veya bos durum + "New Company" butonu |
| Deals | Deal listesi veya "No deals found" + "Create deal" butonu, Search, Filter, Export |

---

## Test 5: Dark/Light Mode Toggle

### Adimlar

```
1. take_snapshot() → "Toggle light/dark mode" butonunu bul
2. click(uid=<toggle_button>)
3. take_screenshot()
   → Tema degismis olmali (koyu → acik veya tersi)
```

---

## Otomatik Test Script (Bash + Chrome DevTools)

Deploy sonrasi hizli smoke test icin asagidaki adimlari sirayla calistir:

```bash
# Pre-flight: Supabase erisilebilir mi?
SB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://supabase-supabase-7d9184-178-230-66-156.traefik.me/rest/v1/)
if [ "$SB_STATUS" != "401" ]; then
  echo "FAIL: Supabase API erisimi yok (HTTP $SB_STATUS)"
  echo "Fix: docker network connect supabase-supabase-0qdhd3 dokploy-traefik"
  exit 1
fi

# Frontend erisilebilir mi?
FE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3015/)
if [ "$FE_STATUS" != "200" ]; then
  echo "FAIL: Frontend erisimi yok (HTTP $FE_STATUS)"
  echo "Fix: docker ps | grep atomic → container UP mi?"
  exit 1
fi

# Auth autoconfirm aktif mi?
AUTH_CONF=$(docker exec supabase-supabase-0qdhd3-supabase-auth env 2>/dev/null | grep GOTRUE_MAILER_AUTOCONFIRM | cut -d= -f2)
if [ "$AUTH_CONF" != "true" ]; then
  echo "WARN: Email autoconfirm OFF — signup calismayabilir"
fi

echo "PASS: Pre-flight checks OK (Supabase=$SB_STATUS, Frontend=$FE_STATUS, AutoConfirm=$AUTH_CONF)"
echo "Browser testleri icin Chrome DevTools MCP kullan"
```

---

## Ogrenilen Tuzaklar (Browser Test Sirasinda)

### Tuzak 1: traefik.me DNS → 127.0.0.1
**Belirti:** Network tab'da `ERR_CONNECTION_REFUSED` — tum Supabase API istekleri basarisiz.
**Neden:** `/etc/hosts`'da `127.0.0.1 supabase-...traefik.me` var, Traefik `192.168.2.13:80`'de.
**Fix:** `/etc/hosts` IP'sini `192.168.2.13`'e degistir.

### Tuzak 2: Traefik Network Izolasyonu → 504
**Belirti:** `/etc/hosts` duzeltildi ama API istekleri `504 Gateway Timeout` veriyor.
**Neden:** Traefik (`dokploy-network`) ve Kong (`supabase-supabase-0qdhd3`) farkli network'lerde.
**Fix:** `docker network connect supabase-supabase-0qdhd3 dokploy-traefik`
**Dikkat:** Supabase redeploy sonrasi KOPABiLiR — her seferinde kontrol et.

### Tuzak 3: Signup "Creating..." Sonra Geri Donuyor → 500
**Belirti:** Buton "Creating..." olur, 5sn sonra form'a geri doner, hata mesaji yok.
**Neden:** Network tab → `POST /auth/v1/signup → 500` → response: `"Error sending confirmation email"`.
**Fix:** Mail container yok → `ENABLE_EMAIL_AUTOCONFIRM=true` ile auth container restart.

### Tuzak 4: compose-deploy Env Degisikligini Iletmiyor
**Belirti:** REST API ile env guncellendi, compose-deploy yapildi ama container eski env ile calisiyor.
**Neden:** Dokploy bilinen env propagation bug'i.
**Fix:** `docker stop/rm` + `docker compose up -d --no-deps <service>` ile elle restart.

### Tuzak 5: Snapshot uid'leri Sayfa Gecislerinde Degisiyor
**Belirti:** Onceki snapshot'tan alinan uid ile click/fill yapilamiyor → element bulunamiyor.
**Neden:** Her `navigate_page` sonrasi uid'ler yeniden olusturulur.
**Fix:** Her sayfa gecisinden sonra `take_snapshot()` ile guncel uid'leri al.

---

## Test Sonuclari Sablonu

Her test calistirildiktan sonra bu tabloyu doldur:

```markdown
| Test | Durum | Notlar |
|------|-------|--------|
| Sayfa yuklenmesi (localhost:3015) | PASS/FAIL | |
| Supabase API baglantisi (init_state → 200) | PASS/FAIL | |
| Ilk kullanici signup (admin) | PASS/FAIL | |
| Dashboard onboarding | PASS/FAIL | |
| Contact olusturma | PASS/FAIL | |
| Navigasyon (4 sayfa) | PASS/FAIL | |
| Dark/Light mode | PASS/FAIL | |
| Console'da critical hata yok | PASS/FAIL | |
```

---

*Created: 2026-04-13 | Author: Ayaz + Claude Opus 4.6*
*Based on: Real browser test session with Chrome DevTools MCP*
