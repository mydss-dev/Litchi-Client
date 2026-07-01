// 客户端配置模板
//
// 使用方法：
// 1. 只修改下面引号里的内容，不要改字段名称。
// 2. 保存后把这个 JS 文件发回机器人。
// 3. update_version、下载地址和 SHA-256 不需要填写；
//    打包成功后机器人会自动生成最终 config.json。
// 4. 首次配置或后台版本变化时必须打包。
//    后台版本与上次构建相同时，机器人会让你选择只更新配置或同版本重打。

const payload = {
  // 必填：客户看到的软件名称，1～40 个字符。
  app_name: "示例加速器",

  // 必填：面板 API 地址。必须使用 HTTPS，可按顺序填写多个备用地址。
  api_base_list: [
    "https://api.example.com",
  ],

  // 可选：API 路径前缀。面板接口没有前缀时填写空字符串。
  api_prefix: "/api/v1",

  // 必填：后端面板类型，只能填写以下三种之一：
  // "v2board"、"xiao_v2board"、"xboard"
  // Xiao-V2Board 和 XBoard 的 POST 请求会自动使用表单格式。
  panel_type: "v2board",

  // 高级可选：正常面板不需要填写，客户端会根据 panel_type 自动判断。
  // 只有魔改后端缺少某个接口时，才取消下面注释并覆盖对应功能：
  // panel_features: {
  //   wallet: false,         // 余额充值
  //   traffic: false,        // 流量明细
  //   tickets: false,        // 工单系统
  //   online_devices: false, // 在线设备数/设备限制
  // },

  // 必填：软件 Logo 的公开 HTTPS 地址。
  // 推荐 1024×1024 PNG、透明背景、文件不超过 10 MB。
  // 打包时会自动生成圆角桌面图标、Android 自适应图标和托盘图标；
  // 透明 Logo 与自带背景的完整方形图标都支持，无需手工制作多套尺寸。
  logo_url: "https://cdn.example.com/logo.png",

  // 可选：账户页面头像或品牌图片；不需要时删除这一行。
  avatar_url: "https://cdn.example.com/avatar.png",

  // 建议填写：官网或邀请注册链接的基础地址。
  invite_url_base: "https://www.example.com",

  // 是否启用客户端更新，默认开启：
  // true  = 只有执行 /build 并成功生成更高版本安装包后，
  //         机器人才会自动填写版本、下载地址和 SHA-256，
  //         已安装的客户端随后显示更新提示；
  // false = 机器人仍保存真实版本和安装包信息，但客户端不显示更新提示。
  //
  // 提醒：软件名称和 Logo 会进入原生安装包。只更新配置时，系统图标和
  // 原生名称不会变化；同版本重打只影响之后新下载安装的用户，
  // 已安装用户的图标和原生名称不会变化，必须等下次提高版本并安装更新后生效。
  update_enabled: true,

  // 可选：更新时展示给客户的说明，最多 200 个字符。
  update_changelog: "修复已知问题并优化连接体验",
};
