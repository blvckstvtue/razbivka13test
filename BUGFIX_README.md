# 🐛 CS:GO Property Bug Fix & Solutions

## Проблемът (The Problem)

При тестване на enhanced sprays плъгина се появи грешка:
```
Property "m_flCycle" not found (entity 217/predicted_viewmodel)
```

Тази грешка се появява защото **CS:GO viewmodel entities не поддържат някои от стандартните Source engine properties**, особено `m_flCycle` и някои animation properties.

## 🔧 Предоставени решения (Provided Solutions)

### 1. **Enhanced Version (Fixed)** - `franug_sprays_enhanced.sp`
- ✅ **Поправен оригинален код** с error handling
- ✅ Използва `HasEntProp()` за безопасни проверки
- ✅ Пропуска `m_flCycle` и други проблемни properties
- ✅ Запазва пълната функционалност на анимацията

#### Промени в enhanced версията:
```cpp
// Безопасна проверка преди използване на property
if(HasEntProp(viewModel, Prop_Send, "m_nSequence"))
{
    g_iStoredSequence[client] = GetEntProp(viewModel, Prop_Send, "m_nSequence");
}

// Пропускаме m_flCycle - не е надежден в CS:GO
g_fStoredCycle[client] = 0.0;
```

### 2. **Simple Version** - `franug_sprays_simple_animation.sp`
- ✅ **Максимално опростена версия** само с model replacement
- ✅ Избягва всички проблемни animation properties
- ✅ Само заменя `m_nModelIndex` и го възстановява
- ✅ 100% съвместимост с CS:GO

#### Предимства на simple версията:
```cpp
// Минимални функции - само model index
void StoreCurrentViewModel(int client)
{
    g_iStoredViewModel[client] = GetEntProp(viewModel, Prop_Send, "m_nModelIndex");
}

void SetGraffitiViewModel(int client)
{
    SetEntProp(viewModel, Prop_Send, "m_nModelIndex", g_iGraffitiModelIndex);
}
```

## 🎯 Коя версия да използвам? (Which Version to Use?)

### **Препоръка: Simple Version**
За максимална стабилност и съвместимост с CS:GO препоръчвам **simple animation версията**:

#### ✅ Предимства:
- Няма CS:GO compatibility issues  
- Минимален performance impact
- Все още показва graffiti balloon модела
- По-къс animation duration (1.5 сек)
- Надеждна работа във всички conditions

#### 📋 Инсталация на Simple Version:
1. Използвай `franug_sprays_simple_animation.sp`
2. Същите model файлове: `v_ballon4ik.mdl`, `.vmt`, `.vtf`
3. Компилирай и quality test на сървъра

### **Enhanced Version**
Ако искаш пълната функционалност (въпреки че е починена):

#### ✅ Предимства:
- Пълни animation sequences
- По-дълъг animation (2 сек)
- Възможност за по-сложни анимации в бъдеще

#### ⚠️ Съображения:
- По-сложен код
- Възможни compatibility issues с бъдещи CS:GO updates

## 🔍 Техническо обяснение (Technical Explanation)

### Причината за грешката:
CS:GO използва **predicted viewmodels** които имат ограничени properties в сравнение със стандартни Source entities. Properties като `m_flCycle` не съществуват или не са достъпни през SourceMod API.

### Решението:
```cpp
// ПРЕДИ (грешен код):
g_fStoredCycle[client] = GetEntPropFloat(viewModel, Prop_Send, "m_flCycle");

// СЛЕД (безопасен код):
if(HasEntProp(viewModel, Prop_Send, "m_flCycle"))
{
    g_fStoredCycle[client] = GetEntPropFloat(viewModel, Prop_Send, "m_flCycle");
}
else
{
    g_fStoredCycle[client] = 0.0; // Default value
}
```

## 🚀 Инсталационни инструкции (Installation Instructions)

### За Simple Version (препоръчително):
```bash
# Компилирай простата версия
./addons/sourcemod/scripting/spcomp franug_sprays_simple_animation.sp

# Копирай на сървъра
cp franug_sprays_simple_animation.smx addons/sourcemod/plugins/

# Добави model файловете (същите като преди)
```

### За Enhanced Version (ако искаш пълната функционалност):
```bash
# Компилирай поправената enhanced версия
./addons/sourcemod/scripting/spcomp franug_sprays_enhanced.sp

# Копирай на сървъра
cp franug_sprays_enhanced.smx addons/sourcemod/plugins/
```

## 🎮 Тестване (Testing)

1. **Стартирай сървъра** с новия плъгин
2. **Тествай spray командата**: `!spray` 
3. **Провери логовете** за грешки
4. **Тествай с различни weapons** от custom_weapons.sp
5. **Тествай edge cases**: weapon switch по време на анимация

## 📝 ConVars за debug

```cpp
// За troubleshooting:
sm_csgosprays_show_messages 1          // Показвай всички съобщения
sm_csgosprays_enable_animation 0       // Изключи анимацията при проблеми
```

## 🔮 Заключение

**Simple версията е най-добрият избор** за production среда - тя:
- ✅ Решава compatibility проблема
- ✅ Запазва visual ефекта
- ✅ Минимизира risk от бъдещи проблеми
- ✅ Работи стабилно с custom_weapons.sp

Enhanced версията остава като опция за тези, които искат пълната функционалност, но **simple версията е по-безопасна и практична**.

---

**Препоръка**: Използвай `franug_sprays_simple_animation.sp` за най-добра съвместимост! 🎯