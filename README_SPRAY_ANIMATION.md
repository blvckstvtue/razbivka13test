# CS:GO Enhanced Sprays with Graffiti Balloon Animation

## Обзор (Overview)

Това е подобрена версия на оригиналния SM Franug CSGO Sprays плъгин, която добавя красива анимация с ballon4ik модел по време на спрейване. Системата е проектирана да работи безпроблемно с custom_weapons.sp плъгина.

This is an enhanced version of the original SM Franug CSGO Sprays plugin that adds a beautiful graffiti balloon animation during spraying. The system is designed to work seamlessly with the custom_weapons.sp plugin.

## 🎯 Ключови Особености (Key Features)

### ✨ Нови функции (New Features)
- **Анимация на спрейване**: Временно заменя viewmodel-a с graffiti balloon по време на спрейване
- **Безконфликтна интеграция**: Работи с custom_weapons.sp без проблеми
- **Умно възстановяване**: Автоматично възстановява оригиналния weapon model след анимацията
- **Конфигурируема система**: Можете да включите/изключите анимацията по желание

### 🔧 Оригинални функции (Original Features)
- Spray система за CS:GO
- Cooldown между спрейове
- Персистентни спрейове на картата
- Cookie система за запазване на настройки
- USE ключ поддръжка (E)

## 🚀 Инсталация (Installation)

### 1. Файлове (Files Required)
```
├── addons/sourcemod/plugins/
│   └── franug_sprays_enhanced.smx
├── addons/sourcemod/scripting/
│   └── franug_sprays_enhanced.sp
├── models/12konsta/graffiti/
│   └── v_ballon4ik.mdl
└── materials/Models/12konsta/graffiti/
    ├── v_ballon4ik.vmt
    └── v_ballon4ik.vtf
```

### 2. Конфигурация (Configuration)
Плъгинът автоматично създава конфигурационен файл: `cfg/sourcemod/plugin.franug_sprays_enhanced.cfg`

### 3. ConVars
```cpp
// Оригинални настройки
sm_csgosprays_time "30"                    // Cooldown между спрейове (секунди)
sm_csgosprays_distance "115"              // Максимално разстояние до стената
sm_csgosprays_use "1"                     // Спрейване с USE ключ (E)
sm_csgosprays_mapmax "25"                 // Максимум спрейове на картата
sm_csgosprays_reset_time_on_kill "1"     // Нулиране на cooldown при убийство
sm_csgosprays_show_messages "1"          // Показване на съобщения

// НОВА настройка за анимация
sm_csgosprays_enable_animation "1"       // Включване/изключване на анимацията
```

## 🔄 Как работи системата (How the System Works)

### Стъпки на анимацията (Animation Steps):

1. **Проверка за конфликт**: Проверява дали вече играе spray анимация
2. **Запазване на състояние**: Записва текущия viewmodel, sequence и cycle
3. **Заменяне на модел**: Временно заменя с graffiti balloon модела
4. **Пускане на анимация**: Стартира "pshh" анимационната последователност
5. **Създаване на спрей**: Поставя спрей decal-a на стената
6. **Възстановяване**: Автоматично връща оригиналния weapon model след 2 секунди

### Интеграция с Custom Weapons:

```cpp
// Запазване на текущо състояние
void StoreCurrentViewModel(int client)
{
    int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
    if(viewModel > 0)
    {
        g_iStoredViewModel[client] = GetEntProp(viewModel, Prop_Send, "m_nModelIndex");
        g_iStoredSequence[client] = GetEntProp(viewModel, Prop_Send, "m_nSequence");
        g_fStoredCycle[client] = GetEntPropFloat(viewModel, Prop_Send, "m_flCycle");
    }
}

// Възстановяване
void RestoreOriginalViewModel(int client)
{
    int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
    if(viewModel > 0)
    {
        SetEntProp(viewModel, Prop_Send, "m_nModelIndex", g_iStoredViewModel[client]);
        SetEntProp(viewModel, Prop_Send, "m_nSequence", g_iStoredSequence[client]);
        SetEntPropFloat(viewModel, Prop_Send, "m_flCycle", g_fStoredCycle[client]);
    }
}
```

## 🎮 Команди (Commands)

- `!spray` / `sm_spray` - Направи спрей
- `!sprays` / `sm_sprays` - Избери спрей от менюто

## ⚠️ Предпазни мерки (Safety Measures)

### Защита от конфликти:
- Проверява дали вече се изпълнява spray анимация
- Почиства timer-и при disconnect/death
- Възстановява viewmodel при неочаквано прекъсване

### Memory Management:
```cpp
public void OnClientDisconnect(int client)
{
    // Почистване на animation timer
    if(g_hAnimTimer[client] != INVALID_HANDLE)
    {
        KillTimer(g_hAnimTimer[client]);
        g_hAnimTimer[client] = INVALID_HANDLE;
    }
    
    // Reset на animation state
    g_bIsPlayingSprayAnim[client] = false;
    // ... други почиствания
}
```

## 🔧 Troubleshooting

### Проблем: Анимацията не се показва
**Решение**: 
1. Проверете дали `sm_csgosprays_enable_animation` е "1"
2. Уверете се, че model файловете са качени правилно
3. Проверете за грешки в логовете

### Проблем: Конфликт с custom_weapons.sp
**Решение**: 
1. Системата е проектирана да работи безпроблемно
2. Ако има проблеми, изключете анимацията: `sm_csgosprays_enable_animation 0`

### Проблем: Viewmodel не се възстановява
**Решение**: 
1. Плъгинът автоматично почиства при disconnect/death
2. Рестартирайте сървъра при сериозни проблеми

## 📈 Performance Impact

- **Минимален impact**: Системата използва само viewmodel промени
- **Memory efficient**: Почиства всички timer-и и състояния
- **Network optimized**: Използва съществуващи SourceMod функции

## 🔄 Migration от оригинален

За да мигрирате от оригиналния franug sprays:

1. Заменете стария .sp файл с новия
2. Компилирайте новия плъгин  
3. Добавете model файловете
4. Рестартирайте сървъра
5. Настройте `sm_csgosprays_enable_animation` по желание

## 📝 Changelog

### v1.5.0
- ➕ Добавена graffiti balloon анимация
- ➕ Интеграция с custom_weapons.sp
- ➕ Нова конфигурационна опция за анимация
- ⚡ Подобрено memory management
- 🔧 Защита от конфликти

### v1.4.5 (Original)
- Оригинален функционалност на Franc1sco

---

**Автор на оригинала**: Franc1sco  
**Enhanced by**: Assistant  
**Версия**: 1.5.0  
**Съвместимост**: CS:GO, SourceMod 1.8+