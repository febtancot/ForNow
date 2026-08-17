import UniformTypeIdentifiers

/// 面板可接收拖入的内容类型（文件、音频/录音、图片、链接、文字）。
/// 语音备忘录等来源常只提供 `public.audio`/文件承诺，而不是直接提供 fileURL。
let supportedDropTypes: [UTType] = [.fileURL, .audio, .image, .url, .text]
