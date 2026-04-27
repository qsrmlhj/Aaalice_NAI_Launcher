import 'workflow_template.dart';

/// 内置工作流模板定义
class BuiltinWorkflows {
  BuiltinWorkflows._();

  static List<WorkflowTemplate> get all => [
        seedvr2Upscale,
        modelUpscale,
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
  static const WorkflowTemplate seedvr2Upscale = WorkflowTemplate(
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
      WorkflowSlot(
        id: 'input_image',
        direction: SlotDirection.input,
        dataType: SlotDataType.image,
        nodeId: '15',
        field: 'image',
        label: '输入图像',
        required: true,
      ),
      // 参数：放大倍数
      WorkflowSlot(
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
      WorkflowSlot(
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
      WorkflowSlot(
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
      WorkflowSlot(
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

  /// ComfyUI 普通超分模型工作流
  ///
  /// 节点图：
  ///   [1] LoadImage (输入)
  ///     ├─> [3] ImageUpscaleWithModel
  ///     │    └── upscale_model <── [2] UpscaleModelLoader
  ///     ├─> [4] ImageScale (Lanczos 缩放到用户指定最终尺寸)
  ///     └─> [5] SaveImage
  ///
  /// 这种流程用于 `models/upscale_models` 里的 `.pth/.pt/.safetensors`
  /// 等轻量超分模型；模型本身先输出原生倍率，再由 Lanczos 统一修正到
  /// 启动器中设置的目标倍率。
  static const WorkflowTemplate modelUpscale = WorkflowTemplate(
    id: 'builtin_comfy_model_upscale',
    name: 'ComfyUI 普通超分模型',
    description: '使用 ComfyUI UpscaleModelLoader 加载普通超分模型，并用 Lanczos 修正最终倍率',
    version: '1.0.0',
    author: 'NAI Launcher',
    category: WorkflowCategory.enhance,
    requiresInputImage: true,
    requiresMask: false,
    isBuiltin: true,
    slots: [
      WorkflowSlot(
        id: 'input_image',
        direction: SlotDirection.input,
        dataType: SlotDataType.image,
        nodeId: '1',
        field: 'image',
        label: '输入图像',
        required: true,
      ),
      WorkflowSlot(
        id: 'upscale_model',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.choice,
        nodeId: '2',
        field: 'model_name',
        label: '超分模型',
        defaultValue: 'realesrganX4plusAnime_v1.pt',
        choices: ['realesrganX4plusAnime_v1.pt'],
      ),
      WorkflowSlot(
        id: 'target_width',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '4',
        field: 'width',
        label: '目标宽度',
        defaultValue: 1024,
        min: 1,
        max: 16384,
      ),
      WorkflowSlot(
        id: 'target_height',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '4',
        field: 'height',
        label: '目标高度',
        defaultValue: 1024,
        min: 1,
        max: 16384,
      ),
      WorkflowSlot(
        id: 'output_image',
        direction: SlotDirection.output,
        dataType: SlotDataType.image,
        nodeId: '5',
        field: null,
        label: '输出图像',
        outputMethod: OutputMethod.httpHistory,
        nodeClass: 'SaveImage',
      ),
    ],
    workflowJson: _modelUpscaleWorkflowJson,
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

  // ==================== 普通超分模型 ====================

  static const Map<String, dynamic> _modelUpscaleWorkflowJson = {
    '1': {
      'inputs': {
        'image': 'placeholder.png',
      },
      'class_type': 'LoadImage',
      '_meta': {'title': 'Load Image'},
    },
    '2': {
      'inputs': {
        'model_name': 'realesrganX4plusAnime_v1.pt',
      },
      'class_type': 'UpscaleModelLoader',
      '_meta': {'title': 'Upscale Model Loader'},
    },
    '3': {
      'inputs': {
        'upscale_model': ['2', 0],
        'image': ['1', 0],
      },
      'class_type': 'ImageUpscaleWithModel',
      '_meta': {'title': 'Image Upscale With Model'},
    },
    '4': {
      'inputs': {
        'upscale_method': 'lanczos',
        'width': 1024,
        'height': 1024,
        'crop': 'disabled',
        'image': ['3', 0],
      },
      'class_type': 'ImageScale',
      '_meta': {'title': 'Image Scale To Target'},
    },
    '5': {
      'inputs': {
        'filename_prefix': 'NAI_upscale',
        'images': ['4', 0],
      },
      'class_type': 'SaveImage',
      '_meta': {'title': 'Save Image'},
    },
  };
}
