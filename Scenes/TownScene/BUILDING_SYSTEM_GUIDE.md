# 城镇建筑系统使用指南

## 概述
城镇场景现在采用了混合建筑系统，结合了TileMapLayer和独立的Area2D节点，为您的SteamWorld Dig风格挖矿游戏提供了灵活的建筑管理。

## 系统架构

### 🏗️ 建筑类型
建筑系统支持两种类型的建筑：

1. **可交互建筑** - 玩家可以进入的功能性建筑
   - 商店：购买和升级装备
   - 矿井入口：进入挖矿区域

2. **装饰建筑** - 纯视觉效果的建筑
   - 民居：增加城镇的生活感

### 🔧 技术实现

#### TileMapLayer vs 独立Sprites
- **TileMapLayer**: 用于地面瓦片和背景装饰
- **独立Area2D节点**: 用于可交互建筑，提供碰撞检测和交互功能

#### 数据驱动系统
建筑通过`buildings_data`字典进行配置：

```gdscript
var buildings_data = {
    "building_id": {
        "name": "建筑名称",
        "position": Vector2(x, y),
        "size": Vector2(width, height),
        "color": Color(r, g, b),
        "scene_path": "res://path/to/scene.tscn"  # null表示装饰建筑
    }
}
```

## 🎮 游戏功能

### 玩家交互
- **接近提示**: 当玩家接近可交互建筑时显示"按空格键进入"
- **进入建筑**: 按下空格键进入当前建筑
- **返回城镇**: 按ESC键返回开始菜单

### 相机系统
- 相机自动跟随玩家移动
- 适当的缩放比例(0.8x)提供最佳视野

## 🛠️ 自定义建筑

### 添加新建筑
1. 在`buildings_data`字典中添加新条目
2. 如果是可交互建筑，创建对应的场景文件
3. 系统会自动创建建筑并设置交互

### 修改现有建筑
- 调整`position`: 更改建筑在城镇中的位置
- 修改`size`: 调整建筑的外观尺寸
- 更换`color`: 改变建筑的颜色主题
- 设置`scene_path`: 指定进入建筑后跳转的场景

## 📁 文件结构
```
TownScene/
├── TownScene.tscn      # 场景文件
├── TownScene.gd        # 主要脚本
├── BUILDINGS_CONFIG.md # 建筑配置指南
└── README.md          # 场景说明
```

## 🎨 视觉效果

### 当前外观
- 建筑使用ColorRect显示，带有不同颜色区分
- 每个建筑都有标签显示名称
- 可交互建筑有接近提示

### 未来改进建议
- 使用精美的sprite纹理替换ColorRect
- 添加建筑动画效果
- 实现昼夜循环的灯光效果
- 添加音效和粒子效果

## 🔧 开发者注意事项

### 扩展性
- 系统设计为易于扩展
- 新建筑类型可以轻松添加
- 支持不同的交互模式

### 性能考虑
- 建筑在场景启动时创建，运行时性能良好
- Area2D检测仅在玩家接近时激活
- 内存使用优化

### 错误处理
- GameManager连接失败时的降级处理
- 场景文件缺失时的错误提示
- 节点引用的安全检查

## 🎯 下一步开发
1. 创建ShopScene和MineScene的具体内容
2. 实现建筑内部的功能逻辑
3. 添加更多建筑类型（铁匠铺、旅馆等）
4. 实现建筑升级系统
5. 添加建筑解锁机制

---

建筑系统现在已经完全实现并经过测试，为您的挖矿游戏提供了坚实的基础！
