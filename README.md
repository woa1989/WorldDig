# World Dig - 挖掘游戏

一个类似SteamWorld Dig的2D挖掘冒险游戏，使用Godot 4.4制作。

## 项目结构

```
WorldDig/
├── Player/                 # 玩家角色资源
│   ├── Player.tscn        # 玩家场景
│   └── Assets/            # 玩家动画资源
├── Scenes/                # 游戏场景
│   ├── StartScene/        # 开始场景
│   ├── TownScene/         # 城镇场景
│   ├── MineScene/         # 矿井场景
│   └── ShopScene/         # 商店场景
├── Singletons/            # 单例脚本
│   └── GameManager.gd     # 游戏管理器
└── project.godot          # Godot项目配置
```

## 游戏流程

1. **开始场景**: 游戏启动界面
2. **城镇场景**: 游戏主基地，可以访问商店和矿井
3. **商店场景**: 购买升级和道具
4. **矿井场景**: 挖掘和收集资源

## 核心系统

### GameManager (游戏管理器)
- 全局状态管理
- 金币系统
- 玩家属性管理
- 场景切换

### 挖掘系统
- 程序化地形生成
- 不同深度的材料分布
- 资源价值系统

### 升级系统
- 镐子升级 (提升挖掘效率)
- 生命值升级
- 移动速度升级

## 控制说明

- **WASD/方向键**: 移动
- **J**: 挖掘
- **空格**: 跳跃
- **ESC**: 返回上级场景

## 技术特性

- 使用Godot 4.4引擎
- 场景化架构设计
- 单例模式管理全局状态
- 信号系统实现组件通信
- 模块化文件组织

## 开发状态

- ✅ 基础场景结构
- ✅ 游戏管理系统
- ✅ 基础UI界面
- 🚧 玩家控制系统
- 🚧 挖掘系统实现
- 🚧 美术资源整合
- ⏳ 音效系统
- ⏳ 存档系统
