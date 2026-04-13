# Terminal Setup Karşılaştırması
> Araştırma Tarihi: 2025-01-28

---

## 🔬 Araştırma Kaynakları

- [awesome-tuis](https://github.com/rothgar/awesome-tuis) - Kapsamlı TUI listesi
- [Modern Terminals Showdown](https://blog.codeminer42.com/modern-terminals-alacritty-kitty-and-ghostty/) - Terminal karşılaştırması
- [Tmux vs Zellij](https://tmuxai.dev/tmux-vs-zellij/) - Multiplexer karşılaştırması
- [Helix vs Neovim](https://tqwewe.com/blog/helix-vs-neovim/) - Editor karşılaştırması
- [Zsh vs Fish](https://medium.com/@awaleedpk/zsh-vs-fish-the-ultimate-shell-showdown-for-2025-27b89599859b) - Shell karşılaştırması

---

## Setup 1: Tmux-Centric (Screenshot)
```
Terminal Emulator (Wezterm/Alacritty)
└── Tmux (multiplexer)
    └── Neovim
        ├── nvim-tree (file explorer)
        ├── telescope (fuzzy finder)
        ├── lualine (status bar)
        └── symbols-outline (code outline)
```

**Özellikler:**
- Tek terminal penceresi içinde her şey
- Tab'lar ve split'ler tmux ile
- Plugin-heavy Neovim config
- Klasik, battle-tested yaklaşım

---

## Setup 2: Niri + Yazi + Nvim (Modüler)
```
Niri (Wayland Compositor)
├── Yazi (file manager) ──────► Nvim'e dosya açar
├── Nvim (editor)
├── Terminal (foot/alacritty)
└── Diğer uygulamalar
```

**Bileşenler:**
| Araç | Açıklama | Dil |
|------|----------|-----|
| Niri | Scrolling tiling Wayland compositor | Rust |
| Yazi | Blazing fast file manager | Rust |
| Nvim | Text editor | C/Lua |

**Özellikler:**
- Her araç tek bir iş yapıyor (Unix felsefesi)
- Yazi: image/video preview, mouse desteği
- Niri: Smooth animasyonlar, infinite scroll workspace
- Modüler: Parçaları bağımsız değiştirebilirsin

---

## Karşılaştırma Tablosu

| Kriter | Setup 1 (Tmux) | Setup 2 (Niri) |
|--------|----------------|----------------|
| **UI Modernliği** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Kolay Yönetim** | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Mouse Desteği** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Performans** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Öğrenme Eğrisi** | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Esneklik** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Stabilite** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ (niri yeni) |
| **X11 Uyumluluk** | ✅ | ❌ (Wayland only) |

---

## Mouse Destekli TUI Setup Önerileri

### Seçenek A: Yazi-Centric (En iyi mouse desteği)
```
Yazi (file manager) - TAM mouse desteği
├── Mouse ile navigate
├── Click to select
├── Drag & drop (yakında)
├── Image preview
└── $EDITOR ile nvim entegrasyonu
```

### Seçenek B: Tmux + Mouse
```bash
# ~/.tmux.conf
set -g mouse on
```
- Pane resize with mouse
- Click to select pane
- Scroll with mouse wheel

### Seçenek C: Neovim Mouse
```lua
-- init.lua
vim.opt.mouse = 'a'
vim.opt.mousemoveevent = true
```
- Click to position cursor
- Select text with mouse
- Scroll support

### Seçenek D: Hibrit (Önerilen)
```
Niri/Hyprland (compositor)
├── Yazi (mouse-friendly file manager)
├── Neovim (mouse=a enabled)
├── Lazygit (TUI git, mouse destekli)
└── btop/htop (system monitor, mouse destekli)
```

---

## Öneriler

### En Gelişmiş UI İstiyorsan:
**Niri + Yazi + Nvim** → Modern, animasyonlu, image preview

### En Kolay Yönetim İstiyorsan:
**Niri + Yazi + Nvim** → Her config ayrı, modüler

### Stabilite Öncelikli:
**Tmux + Neovim** → Yıllardır test edilmiş

### Mouse Odaklı:
**Yazi + Neovim** → Her ikisi de tam mouse desteği

---

## Kurulum Notları

### Niri Kurulum (Fedora)
```bash
sudo dnf copr enable yalter/niri
sudo dnf install niri
```

### Yazi Kurulum
```bash
cargo install --locked yazi-fm yazi-cli
# veya
brew install yazi
```

### Entegrasyon (Yazi → Nvim)
```bash
# ~/.config/yazi/yazi.toml
[opener]
edit = [
  { run = 'nvim "$@"', block = true }
]
```

---

---

# 🔍 DERİN ANALİZ (Araştırma Sonuçları)

## Terminal Emulator Karşılaştırması

| Terminal | GPU | Özellik | Performans | Mouse | Önerilen Kullanım |
|----------|-----|---------|------------|-------|-------------------|
| **Ghostty** | ✅ Zig/Native | Orta | ⭐⭐⭐⭐⭐ | ✅ | Hız + sadelik isteyenler |
| **WezTerm** | ✅ WebGPU | Çok yüksek | ⭐⭐⭐⭐ | ✅ | Lua scripting, remote workflow |
| **Kitty** | ✅ OpenGL | Yüksek | ⭐⭐⭐⭐ | ✅ | Image protocol, kittens |
| **Alacritty** | ✅ OpenGL | Minimal | ⭐⭐⭐⭐⭐ | ✅ | Pure speed, tmux ile |

**Mouse için en iyi:** WezTerm veya Kitty (daha fazla feature)

---

## Terminal Multiplexer Karşılaştırması

| Özellik | Tmux | Zellij |
|---------|------|--------|
| **Öğrenme eğrisi** | Dik | Kolay |
| **Mouse desteği** | Config gerekli | Varsayılan |
| **UI keybind gösterimi** | ❌ | ✅ Ekranda gösterir |
| **Plugin sistemi** | ❌ | ✅ WASM |
| **Stabilite** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Floating panes** | ❌ | ✅ |
| **Session management** | ✅ Güçlü | ✅ |

**Mouse için en iyi:** Zellij (out-of-box mouse, görsel keybinds)

---

## Shell Karşılaştırması

| Özellik | Bash | Zsh | Fish |
|---------|------|-----|------|
| **Autosuggestion** | ❌ | Plugin ile | ✅ Built-in |
| **Syntax highlight** | ❌ | Plugin ile | ✅ Built-in |
| **POSIX uyumlu** | ✅ | ✅ | ❌ |
| **Kurulum kolaylığı** | - | Orta | Çok kolay |
| **Startup hızı** | Hızlı | Plugin'e bağlı | Hızlı |

**Önerim:** Fish (out-of-box deneyim) veya Zsh + Starship (POSIX gerekirse)

---

## Editor Karşılaştırması

| Özellik | Neovim | Helix |
|---------|--------|-------|
| **Kurulum** | Config gerekli | Hazır gelir |
| **LSP** | Plugin ile | ✅ Built-in |
| **Treesitter** | Plugin ile | ✅ Built-in |
| **Mouse** | ✅ `mouse=a` | ✅ |
| **Multi-cursor** | Plugin ile | ✅ Built-in |
| **Plugin sistemi** | ✅ Lua, çok güçlü | ❌ Henüz yok |
| **File tree** | Plugin ile | ❌ Yok (Yazi ile) |
| **Öğrenme** | vim motions | selection-first |

**Yeni başlayanlar için:** Helix
**Max özelleştirme:** Neovim + LazyVim

---

## File Manager Karşılaştırması

| Özellik | Yazi | ranger | lf | nnn |
|---------|------|--------|----|----|
| **Dil** | Rust | Python | Go | C |
| **Hız** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Mouse** | ✅ Tam | Kısıtlı | Kısıtlı | Kısıtlı |
| **Image preview** | ✅ Çoklu protokol | ✅ | Kısıtlı | ❌ |
| **UI** | Modern | Klasik | Minimal | Minimal |
| **Async I/O** | ✅ | ❌ | ❌ | ✅ |

**Mouse için en iyi:** Yazi (açık ara)

---

## 🖱️ MOUSE DESTEKLİ TUI ARAÇLARI

### Tam Mouse Desteği Olanlar
```
✅ Yazi ────────── File manager (click, scroll, select)
✅ Lazygit ─────── Git TUI (click navigation)
✅ Lazydocker ──── Docker TUI (click navigation)
✅ btop ─────────── System monitor (click, scroll)
✅ gitui ────────── Git TUI (Rust, fast)
✅ bottom ───────── System monitor (Rust)
✅ k9s ──────────── Kubernetes TUI
```

### Kısıtlı Mouse Desteği
```
⚠️ htop ─────────── Basic click
⚠️ ranger ───────── Scroll only
⚠️ tig ──────────── Basic navigation
```

---

# 🏆 SETUP ÖNERİLERİ

## Setup A: "Mouse-First Modern" (ÖNERİLEN)

```
GNOME (compositor - değişmiyor)
│
├── Terminal: Kitty veya WezTerm
│   └── GPU accelerated, image protocol, mouse-friendly
│
├── Multiplexer: Zellij
│   └── Native mouse, görsel keybinds, floating panes
│
├── Shell: Fish + Starship
│   └── Zero-config autosuggestion, güzel prompt
│
├── File Manager: Yazi
│   └── Blazing fast, TAM mouse, image preview
│
├── Editor: Neovim + LazyVim (veya Helix)
│   └── mouse=a enabled
│
└── Diğer TUI'lar:
    ├── Lazygit (git)
    ├── Lazydocker (docker)
    └── btop (system monitor)
```

**Artıları:**
- Tüm araçlarda mouse çalışır
- Modern, hızlı (çoğu Rust)
- Kolay öğrenme eğrisi
- Image preview her yerde

---

## Setup B: "Classic Power User"

```
GNOME
│
├── Terminal: Alacritty
├── Multiplexer: Tmux (mouse on)
├── Shell: Zsh + Oh-My-Zsh + Starship
├── File Manager: Neovim içi (nvim-tree)
├── Editor: Neovim (heavily configured)
└── Git: Neovim içi (fugitive + gitsigns)
```

**Artıları:**
- Battle-tested, stabil
- Tek pencerede her şey
- Tmux sessions güçlü

**Eksileri:**
- Config ağır
- Mouse ikinci sınıf vatandaş

---

## Setup C: "Minimal Helix"

```
GNOME
│
├── Terminal: Ghostty (veya Kitty)
├── Multiplexer: Zellij (veya yok)
├── Shell: Fish + Starship
├── File Manager: Yazi
├── Editor: Helix
└── Git: Lazygit
```

**Artıları:**
- Zero-config her şey
- Çok hızlı startup
- Kolay bakım

**Eksileri:**
- Helix plugin yok
- Neovim kadar özelleştirilemez

---

# 📊 SONUÇ MATRİSİ

| Kriter | Setup A | Setup B | Setup C |
|--------|---------|---------|---------|
| **Mouse Desteği** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **UI Modernliği** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Kolay Kurulum** | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Özelleştirme** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Stabilite** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Performans** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Öğrenme Eğrisi** | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |

---

# RECOMMENDATION

**Mouse önemli** dediğin için: **Setup A (Mouse-First Modern)**

```
Kurulum sırası:
1. Kitty veya WezTerm kur
2. Fish + Starship kur
3. Yazi kur (file manager)
4. Zellij kur (tmux alternatifi)
5. Neovim + LazyVim veya Helix
6. Lazygit, btop ekle
```

İstersen kurulum rehberi hazırlarım.

---

## Karar: TBD
Değerlendirme sonrası güncellenecek.
