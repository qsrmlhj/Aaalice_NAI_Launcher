import 'workflow_template.dart';

/// 内置工作流模板定义
class BuiltinWorkflows {
  BuiltinWorkflows._();

  static List<WorkflowTemplate> get all => [
        seedvr2Upscale,
      ];

  /// SeedVR2 超分工作流
  ///
  /// 节点图：
  ///   [15] LoadImage (输入)
  ///     ├─> [9]  imageSizeBySide (取最短边)
  ///     │    └─> [10] NumberCalculatorV2 (最短边 × 放大倍数 = 目标分辨率)
  ///     ├─> [5]  SeedVR2VideoUpscaler (执行超分)
  ///     │    ├── dit <── [6] SeedVR2LoadDiTModel
  ///     │    └── vae <── [7] SeedVR2LoadVAEModel
  ///     └─> [17] SaveImage (保存并通过 HTTP history 获取)
  ///   [18] Float (放大倍数)
  static final WorkflowTemplate seedvr2Upscale = WorkflowTemplate(
    id: 'builtin_seedvr2_upscale',
    name: 'SeedVR2 超分',
    description: '使用 SeedVR2 AI 模型进行超分辨率放大，效果优秀',
    version: '1.0.0',
    author: 'NAI Launcher',
    category: WorkflowCategory.enhance,
    requiresInputImage: true,
    requiresMask: false,
    isBuiltin: true,
    slots: [
      // 输入：源图像
      const WorkflowSlot(
        id: 'input_image',
        direction: SlotDirection.input,
        dataType: SlotDataType.image,
        nodeId: '15',
        field: 'image',
        label: '输入图像',
        required: true,
      ),
      // 参数：放大倍数
      const WorkflowSlot(
        id: 'scale_multiplier',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.number,
        nodeId: '18',
        field: 'Number',
        label: '放大倍数',
        defaultValue: 2.0,
        min: 1.0,
        max: 4.0,
        step: 0.1,
      ),
      // 参数：超分模型
      const WorkflowSlot(
        id: 'dit_model',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.choice,
        nodeId: '6',
        field: 'model',
        label: '超分模型',
        defaultValue: 'seedvr2_ema_7b_fp16.safetensors',
        choices: ['seedvr2_ema_7b_fp16.safetensors'],
      ),
      // 参数：种子
      const WorkflowSlot(
        id: 'seed',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '5',
        field: 'seed',
        label: '随机种子',
        defaultValue: -1,
        min: -1,
        max: 4294967295,
      ),
      // 输出：通过 HTTP history 获取（比 WS 二进制帧更可靠）
      const WorkflowSlot(
        id: 'output_image',
        direction: SlotDirection.output,
        dataType: SlotDataType.image,
        nodeId: '17',
        field: null,
        label: '输出图像',
        outputMethod: OutputMethod.httpHistory,
        nodeClass: 'SaveImage',
      ),
    ],
    workflowJson: _seedvr2WorkflowJson,
  );

  // ==================== SeedVR2 超分 ====================

  static const Map<String, dynamic> _seedvr2WorkflowJson = {
    '5': {
      'inputs': {
        'seed': 454201668,
        'resolution': ['10', 0],
        'max_resolution': 0,
        'batch_size': 1,
        'uniform_batch_size': true,
        'color_correction': 'lab',
        'temporal_overlap': 0,
        'prepend_frames': 0,
        'input_noise_scale': 0,
        'latent_noise_scale': 0,
        'offload_device': 'cpu',
        'enable_debug': false,
        'image': ['15', 0],
        'dit': ['6', 0],
        'vae': ['7', 0],
      },
      'class_type': 'SeedVR2VideoUpscaler',
      '_meta': {'title': 'SeedVR2 Video Upscaler'},
    },
    '6': {
      'inputs': {
        'model': 'seedvr2_ema_7b_fp16.safetensors',
        'device': 'cuda:0',
        'blocks_to_swap': 36,
        'swap_io_components': true,
        'offload_device': 'cpu',
        'cache_model': false,
        'attention_mode': 'sageattn_2',
      },
      'class_type': 'SeedVR2LoadDiTModel',
      '_meta': {'title': 'SeedVR2 Load DiT Model'},
    },
    '7': {
      'inputs': {
        'model': 'ema_vae_fp16.safetensors',
        'device': 'cuda:0',
        'encode_tiled': false,
        'encode_tile_size': 1024,
        'encode_tile_overlap': 128,
        'decode_tiled': false,
        'decode_tile_size': 1024,
        'decode_tile_overlap': 128,
        'tile_debug': 'false',
        'offload_device': 'cpu',
        'cache_model': false,
      },
      'class_type': 'SeedVR2LoadVAEModel',
      '_meta': {'title': 'SeedVR2 Load VAE Model'},
    },
    '9': {
      'inputs': {
        'side': 'Shortest',
        'image': ['15', 0],
      },
      'class_type': 'easy imageSizeBySide',
      '_meta': {'title': 'Image Size By Side'},
    },
    '10': {
      'inputs': {
        'a_value': '',
        'b_value': '',
        'operator': '*',
        'a': ['18', 0],
        'b': ['9', 0],
      },
      'class_type': 'LayerUtility: NumberCalculatorV2',
      '_meta': {'title': 'Number Calculator V2'},
    },
    '15': {
      'inputs': {
        'image': 'placeholder.png',
      },
      'class_type': 'LoadImage',
      '_meta': {'title': 'Load Image'},
    },
    '17': {
      'inputs': {
        'filename_prefix': 'NAI_upscale',
        'images': ['5', 0],
      },
      'class_type': 'SaveImage',
      '_meta': {'title': 'Save Image'},
    },
    '18': {
      'inputs': {
        'Number': 2.0,
      },
      'class_type': 'Float',
      '_meta': {'title': 'API_SCALE_MULTIPLIER'},
    },
  };
}
