// BayerishDitheringShaderPart.hx
package org.flashbacks1998.world3d.shader.parts;

import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import openfl.display.BitmapData;
import openfl.display3D.textures.TextureBase;
import openfl.Vector;

enum BayerishDitheringType { Two; Four; Eight; Sixteen; ThirtyTwo; }
enum QuantizeMode { Luma; PerChannel; }

class BayerishDitheringShaderPart extends ShaderPart {
    // -------------------------------------------------
    // Fragment constants
    // -------------------------------------------------
    // fc0: [W/n, H/n, 0, 0]  (scale for tiling pattern in screen space)
    private final _fragmentConstantSize:Vector<Float> =
        Vector.ofArray([0.0, 0.0, 0.0, 0.0]);

    // fc1: [n, kLuma, modeFlag, _]
    private final _fragmentConstantPacked:Vector<Float> =
        Vector.ofArray([0.0, 0.0, 0.0, 0.0]);

    // fc2: [1, 0.5, 0, 0]
    private final _fragmentConstantEtc:Vector<Float> =
        Vector.ofArray([1.0, 0.5, 0.0, 0.0]);

    // fc3: [0.299, 0.587, 0.114, 0]
    private final _fragmentConstantLuma:Vector<Float> =
        Vector.ofArray([0.299, 0.587, 0.114, 0.0]);

    // fc4: [kR, kG, kB, 0]
    private final _fragmentConstantPerChannelQuantity:Vector<Float> =
        Vector.ofArray([0.0, 0.0, 0.0, 0.0]);

    // -------------------------------------------------
    // Dithering mask texture + matrices
    // -------------------------------------------------
    private var _ditheringTextureMask:TextureBase = null;

    private static var _ditheringMatrix2x2 = [0, 2, 3, 1];

    private static var _ditheringMatrix4x4 = [
         0,  8,  2, 10,
        12,  4, 14,  6,
         3, 11,  1,  9,
        15,  7, 13,  5
    ];

    private static var _ditheringMatrix8x8 = [
         0, 32,  8, 40,  2, 34, 10, 42,
        48, 16, 56, 24, 50, 18, 58, 26,
        12, 44,  4, 36, 14, 46,  6, 38,
        60, 28, 52, 20, 62, 30, 54, 22,
         3, 35, 11, 43,  1, 33,  9, 41,
        51, 19, 59, 27, 49, 17, 57, 25,
        15, 47,  7, 39, 13, 45,  5, 37,
        63, 31, 55, 23, 61, 29, 53, 21
    ];

    private static var _ditheringMatrix16x16 = [
         0, 128,  32, 160,   8, 136,  40, 168,   2, 130,  34, 162,  10, 138,  42, 170,
       192,  64, 224,  96, 200,  72, 232, 104, 194,  66, 226,  98, 202,  74, 234, 106,
        48, 176,  16, 144,  56, 184,  24, 152,  50, 178,  18, 146,  58, 186,  26, 154,
       240, 112, 208,  80, 248, 120, 216,  88, 242, 114, 210,  82, 250, 122, 218,  90,

        12, 140,  44, 172,   4, 132,  36, 164,  14, 142,  46, 174,   6, 134,  38, 166,
       204,  76, 236, 108, 196,  68, 228, 100, 206,  78, 238, 110, 198,  70, 230, 102,
        60, 188,  28, 156,  52, 180,  20, 148,  62, 190,  30, 158,  54, 182,  22, 150,
       252, 124, 220,  92, 244, 116, 212,  84, 254, 126, 222,  94, 246, 118, 214,  86,

         3, 131,  35, 163,  11, 139,  43, 171,   1, 129,  33, 161,   9, 137,  41, 169,
       195,  67, 227,  99, 203,  75, 235, 107, 193,  65, 225,  97, 201,  73, 233, 105,
        51, 179,  19, 147,  59, 187,  27, 155,  49, 177,  17, 145,  57, 185,  25, 153,
       243, 115, 211,  83, 251, 123, 219,  91, 241, 113, 209,  81, 249, 121, 217,  89,

        15, 143,  47, 175,   7, 135,  39, 167,  13, 141,  45, 173,   5, 133,  37, 165,
       207,  79, 239, 111, 199,  71, 231, 103, 205,  77, 237, 109, 197,  69, 229, 101,
        63, 191,  31, 159,  55, 183,  23, 151,  61, 189,  29, 157,  53, 181,  21, 149,
       255, 127, 223,  95, 247, 119, 215,  87, 253, 125, 221,  93, 245, 117, 213,  85
    ];

    // 32x32 is big; keep as-is (your original array)
    private static var _ditheringMatrix32x32 = [
        0, 512, 128, 640, 32, 544, 160, 672, 8, 520, 136, 648, 40, 552, 168, 680, 2, 514, 130, 642, 34, 546, 162, 674, 10, 522, 138, 650, 42, 554, 170, 682,
        768, 256, 896, 384, 800, 288, 928, 416, 776, 264, 904, 392, 808, 296, 936, 424, 770, 258, 898, 386, 802, 290, 930, 418, 778, 266, 906, 394, 810, 298, 938, 426,
        192, 704, 64, 576, 224, 736, 96, 608, 200, 712, 72, 584, 232, 744, 104, 616, 194, 706, 66, 578, 226, 738, 98, 610, 202, 714, 74, 586, 234, 746, 106, 618,
        960, 448, 832, 320, 992, 480, 864, 352, 968, 456, 840, 328, 1000, 488, 872, 360, 962, 450, 834, 322, 994, 482, 866, 354, 970, 458, 842, 330, 1002, 490, 874, 362,

        48, 560, 176, 688, 16, 528, 144, 656, 56, 568, 184, 696, 24, 536, 152, 664, 50, 562, 178, 690, 18, 530, 146, 658, 58, 570, 186, 698, 26, 538, 154, 666,
        816, 304, 944, 432, 784, 272, 912, 400, 824, 312, 952, 440, 792, 280, 920, 408, 818, 306, 946, 434, 786, 274, 914, 402, 826, 314, 954, 442, 794, 282, 922, 410,
        240, 752, 112, 624, 208, 720, 80, 592, 248, 760, 120, 632, 216, 728, 88, 600, 242, 754, 114, 626, 210, 722, 82, 594, 250, 762, 122, 634, 218, 730, 90, 602,
        1008, 496, 880, 368, 976, 464, 848, 336, 1016, 504, 888, 376, 984, 472, 856, 344, 1010, 498, 882, 370, 978, 466, 850, 338, 1018, 506, 890, 378, 986, 474, 858, 346,

        12, 524, 140, 652, 44, 556, 172, 684, 4, 516, 132, 644, 36, 548, 164, 676, 14, 526, 142, 654, 46, 558, 174, 686, 6, 518, 134, 646, 38, 550, 166, 678,
        780, 268, 908, 396, 812, 300, 940, 428, 772, 260, 900, 388, 804, 292, 932, 420, 782, 270, 910, 398, 814, 302, 942, 430, 774, 262, 902, 390, 806, 294, 934, 422,
        204, 716, 76, 588, 236, 748, 108, 620, 196, 708, 68, 580, 228, 740, 100, 612, 206, 718, 78, 590, 238, 750, 110, 622, 198, 710, 70, 582, 230, 742, 102, 614,
        972, 460, 844, 332, 1004, 492, 876, 364, 964, 452, 836, 324, 996, 484, 868, 356, 974, 462, 846, 334, 1006, 494, 878, 366, 966, 454, 838, 326, 998, 486, 870, 358,

        60, 572, 188, 700, 28, 540, 156, 668, 52, 564, 180, 692, 20, 532, 148, 660, 62, 574, 190, 702, 30, 542, 158, 670, 54, 566, 182, 694, 22, 534, 150, 662,
        828, 316, 956, 444, 796, 284, 924, 412, 820, 308, 948, 436, 788, 276, 916, 404, 830, 318, 958, 446, 798, 286, 926, 414, 822, 310, 950, 438, 790, 278, 918, 406,
        252, 764, 124, 636, 220, 732, 92, 604, 244, 756, 116, 628, 212, 724, 84, 596, 254, 766, 126, 638, 222, 734, 94, 606, 246, 758, 118, 630, 214, 726, 86, 598,
        1020, 508, 892, 380, 988, 476, 860, 348, 1012, 500, 884, 372, 980, 468, 852, 340, 1022, 510, 894, 382, 990, 478, 862, 350, 1014, 502, 886, 374, 982, 470, 854, 342,

        3, 515, 131, 643, 35, 547, 163, 675, 11, 523, 139, 651, 43, 555, 171, 683, 1, 513, 129, 641, 33, 545, 161, 673, 9, 521, 137, 649, 41, 553, 169, 681,
        771, 259, 899, 387, 803, 291, 931, 419, 779, 267, 907, 395, 811, 299, 939, 427, 769, 257, 897, 385, 801, 289, 929, 417, 777, 265, 905, 393, 809, 297, 937, 425,
        195, 707, 67, 579, 227, 739, 99, 611, 203, 715, 75, 587, 235, 747, 107, 619, 193, 705, 65, 577, 225, 737, 97, 609, 201, 713, 73, 585, 233, 745, 105, 617,
        963, 451, 835, 323, 995, 483, 867, 355, 971, 459, 843, 331, 1003, 491, 875, 363, 961, 449, 833, 321, 993, 481, 865, 353, 969, 457, 841, 329, 1001, 489, 873, 361,

        51, 563, 179, 691, 19, 531, 147, 659, 59, 571, 187, 699, 27, 539, 155, 667, 49, 561, 177, 689, 17, 529, 145, 657, 57, 569, 185, 697, 25, 537, 153, 665,
        819, 307, 947, 435, 787, 275, 915, 403, 827, 315, 955, 443, 795, 283, 923, 411, 817, 305, 945, 433, 785, 273, 913, 401, 825, 313, 953, 441, 793, 281, 921, 409,
        243, 755, 115, 627, 211, 723, 83, 595, 251, 763, 123, 635, 219, 731, 91, 603, 241, 753, 113, 625, 209, 721, 81, 593, 249, 761, 121, 633, 217, 729, 89, 601,
        1011, 499, 883, 371, 979, 467, 851, 339, 1019, 507, 891, 379, 987, 475, 859, 347, 1009, 497, 881, 369, 977, 465, 849, 337, 1017, 505, 889, 377, 985, 473, 857, 345,

        15, 527, 143, 655, 47, 559, 175, 687, 7, 519, 135, 647, 39, 551, 167, 679, 13, 525, 141, 653, 45, 557, 173, 685, 5, 517, 133, 645, 37, 549, 165, 677,
        783, 271, 911, 399, 815, 303, 943, 431, 775, 263, 903, 391, 807, 295, 935, 423, 781, 269, 909, 397, 813, 301, 941, 429, 773, 261, 901, 389, 805, 293, 933, 421,
        207, 719, 79, 591, 239, 751, 111, 623, 199, 711, 71, 583, 231, 743, 103, 615, 205, 717, 77, 589, 237, 749, 109, 621, 197, 709, 69, 581, 229, 741, 101, 613,
        975, 463, 847, 335, 1007, 495, 879, 367, 967, 455, 839, 327, 999, 487, 871, 359, 973, 461, 845, 333, 1005, 493, 877, 365, 965, 453, 837, 325, 997, 485, 869, 357,

        63, 575, 191, 703, 31, 543, 159, 671, 55, 567, 183, 695, 23, 535, 151, 663, 61, 573, 189, 701, 29, 541, 157, 669, 53, 565, 181, 693, 21, 533, 149, 661,
        831, 319, 959, 447, 799, 287, 927, 415, 823, 311, 951, 439, 791, 279, 919, 407, 829, 317, 957, 445, 797, 285, 925, 413, 821, 309, 949, 437, 789, 277, 917, 405,
        255, 767, 127, 639, 223, 735, 95, 607, 247, 759, 119, 631, 215, 727, 87, 599, 253, 765, 125, 637, 221, 733, 93, 605, 245, 757, 117, 629, 213, 725, 85, 597,
        1023, 511, 895, 383, 991, 479, 863, 351, 1015, 503, 887, 375, 983, 471, 855, 343, 1021, 509, 893, 381, 989, 477, 861, 349, 1013, 501, 885, 373, 981, 469, 853, 341
    ];

    private var _ditheringMatrix:Array<Int> = null;
    private var _ditheringSize:Int = 0;

    // -------------------------------------------------
    // Quantization configuration
    // -------------------------------------------------
    public var levels(get, set):Int;
    public var quantizeMode(get, set):QuantizeMode;

    private var _levels:Int = 4;
    private var _quantizeMode:QuantizeMode = QuantizeMode.PerChannel;

    private var bitsR:Int = 0;
    private var bitsG:Int = 0;
    private var bitsB:Int = 0;

    private var _kLuma:Float = 1.0;
    private var _modeFlag:Float = 1.0;

    public function new(
        type:BayerishDitheringType = BayerishDitheringType.ThirtyTwo,
        levels:Int = 4,
        quantizeMode:QuantizeMode = QuantizeMode.PerChannel
    ) {
        super();

        switch (type) {
            case Two:       _ditheringMatrix = _ditheringMatrix2x2;
            case Four:      _ditheringMatrix = _ditheringMatrix4x4;
            case Eight:     _ditheringMatrix = _ditheringMatrix8x8;
            case Sixteen:   _ditheringMatrix = _ditheringMatrix16x16;
            case ThirtyTwo: _ditheringMatrix = _ditheringMatrix32x32;
        }

        _ditheringSize = Std.int(Math.sqrt(_ditheringMatrix.length));

        _levels = (levels > 0) ? levels : 1;
        _quantizeMode = quantizeMode;

        updateKVec();
    }

    // -------------------------------------------------
    // Upload: build mask texture + register constants
    // -------------------------------------------------
    public override function upload(engine:IRendererEngine):Void {
        Debugger.log("BayerishDitheringShaderPart upload", _ditheringTextureMask);

        // Build Bayer mask texture once
        if (_ditheringTextureMask == null) {
            final n = _ditheringSize;
            final inv_n2 = 1.0 / (n * n);

            final bmpdDithering = new BitmapData(n, n, true, 0x00000000);
            for (x in 0...n) {
                for (y in 0...n) {
                    final index = y * n + x;
                    final value:Int = _ditheringMatrix[index];
                    final intensity = Std.int(((value + 0.5) * inv_n2) * 255.0);
                    final color = (0xFF << 24) | (intensity << 16) | (intensity << 8) | intensity;
                    bmpdDithering.setPixel32(x, y, color);
                }
            }

            _ditheringTextureMask = engine.uploadTexture(bmpdDithering);
        }

        // Ensure texture is listed exactly once
        pushTextureOnce(_ditheringTextureMask);

        // Fragment constants (THIS PART IS FRAGMENT-ONLY)
        pushFragmentConstOnce(_fragmentConstantSize);               // fc0: [W/n, H/n, 0, 0]
        pushFragmentConstOnce(_fragmentConstantPacked);             // fc1: [n,kLuma,modeFlag,_]
        pushFragmentConstOnce(_fragmentConstantEtc);                // fc2: [1,0.5,0,0]
        pushFragmentConstOnce(_fragmentConstantLuma);               // fc3
        pushFragmentConstOnce(_fragmentConstantPerChannelQuantity); // fc4
    }

    // -------------------------------------------------
    // Vertex AGAL: none (fragment reconstructs screen-space)
    // -------------------------------------------------
    public override function getVertexAGALCode(
        agalVersion:Int = -1,
        ?options:{registerConstantOffset:UInt}
    ):String {
        return "mov v7, vt0\n"; // pass clip position to fragment shader
    }

    // -------------------------------------------------
    // Fragment AGAL:
    //  - expects v7 = clip position (vt0 from pipeline vertex prefix)
    //  - reconstructs screenUV
    //  - tiles Bayer mask and quantizes
    // -------------------------------------------------
    public override function getFragmentAGALCode(
        agalVersion:Int = -1,
        ?options:{?registerConstantOffset:UInt, ?registerTextureOffset:UInt}
    ):String {
        final fcOffset = options?.registerConstantOffset ?? 0;
        final ftOffset = options?.registerTextureOffset ?? 0;

        final fcSizeOffset       = fcOffset + _fragmentConstants.indexOf(_fragmentConstantSize);               // fc0
        final fcPackedOffset     = fcOffset + _fragmentConstants.indexOf(_fragmentConstantPacked);             // fc1
        final fcEtcOffset        = fcOffset + _fragmentConstants.indexOf(_fragmentConstantEtc);                // fc2
        final fcLumaOffset       = fcOffset + _fragmentConstants.indexOf(_fragmentConstantLuma);               // fc3
        final fcPerChannelOffset = fcOffset + _fragmentConstants.indexOf(_fragmentConstantPerChannelQuantity); // fc4

        final ftMaskOffset       = ftOffset + _textures.indexOf(_ditheringTextureMask);

        final sSize       = "fc" + fcSizeOffset;        // [W/n, H/n, 0, 0]
        final sPacked     = "fc" + fcPackedOffset;      // [n, kLuma, modeFlag, _]
        final sEtc        = "fc" + fcEtcOffset;         // [1, 0.5, 0, 0]
        final sLuma       = "fc" + fcLumaOffset;        // luma weights
        final sPerChannel = "fc" + fcPerChannelOffset;  // [kR, kG, kB, 0]
        final sMaskTex    = "fs" + ftMaskOffset;

        return
            // ---- Build screen UV from clip-space v7 ----
            // ndc = clip.xy / clip.w  => -1..1
            "div ft6.xy, v7.xy, v7.ww\n" +

            // screenUV = ndc * 0.5 + 0.5  => 0..1
            "mul ft6.xy, ft6.xy, " + sEtc + ".yy\n" +
            "add ft6.xy, ft6.xy, " + sEtc + ".yy\n" +

            // If your pattern is vertically flipped, uncomment this:
            // "sub ft6.y, " + sEtc + ".x, ft6.y\n" +

            // tileCoord = screenUV * (W/n, H/n)
            "mul ft6.xy, ft6.xy, " + sSize + ".xy\n" +

            // IMPORTANT: tex reads a full vec4 coord register; ensure ft6.zw are initialized
            "mov ft6.zw, " + sEtc + ".ww\n" +   // fc2.ww = 0,0

            // sample Bayer mask in repeat mode
            "tex ft1, ft6, " + sMaskTex + " <2d,nearest,repeat,nomip>\n" +

            // ---- Quantization paths ----
            // if (modeFlag == 1) => per-channel; else luma
            "ife " + sPacked + ".z, " + sEtc + ".x\n" +
                // --- Per-channel quantization ---
                "mul ft5.xyz, ft0.xyz, " + sPerChannel + ".xyz\n" +
                "add ft5.xyz, ft5.xyz, ft1.xxx\n" +
                "frc ft3.xyz, ft5.xyz\n" +
                "sub ft5.xyz, ft5.xyz, ft3.xyz\n" +
                "div ft5.xyz, ft5.xyz, " + sPerChannel + ".xyz\n" +
                "mov ft2.xyz, ft5.xyz\n" +
                "mov ft2.w, ft0.w\n" +
            "els\n" +
                // --- Luma quantization ---
                "dp3 ft4.x, ft0.xyz, " + sLuma + ".xyz\n" +
                "mul ft4.x, ft4.x, " + sPacked + ".y\n" +
                "add ft4.x, ft4.x, ft1.x\n" +
                "frc ft3.x, ft4.x\n" +
                "sub ft4.x, ft4.x, ft3.x\n" +
                "div ft4.x, ft4.x, " + sPacked + ".y\n" +
                "mov ft2.x, ft4.x\n" +
                "mov ft2.y, ft4.x\n" +
                "mov ft2.z, ft4.x\n" +
                "mov ft2.w, ft0.w\n" +
            "eif\n" +

            // hand result back to pipeline (pipeline does "mov oc, ft0")
            "mov ft0, ft2\n";
    }

    // -------------------------------------------------
    // Constant updates
    // -------------------------------------------------
    private function updateKVec():Void {
        // fc2
        _fragmentConstantEtc[0] = 1.0;
        _fragmentConstantEtc[1] = 0.5;
        _fragmentConstantEtc[2] = 0.0;
        _fragmentConstantEtc[3] = 0.0;

        // fc3
        _fragmentConstantLuma[0] = 0.299;
        _fragmentConstantLuma[1] = 0.587;
        _fragmentConstantLuma[2] = 0.114;
        _fragmentConstantLuma[3] = 0.0;

        // fc1.x = Bayer size (not required for math here, but useful/debuggable)
        _fragmentConstantPacked[0] = cast(_ditheringSize, Float);

        switch (_quantizeMode) {
            case Luma:
                var levelsBaseLuma:Int = (_levels >= 2) ? _levels : 2;
                var kLumaInt = levelsBaseLuma - 1;
                _kLuma = kLumaInt;
                _modeFlag = 0.0;

                _fragmentConstantPacked[1] = _kLuma;
                _fragmentConstantPacked[2] = _modeFlag; // 0
                _fragmentConstantPacked[3] = 0.0;

                _fragmentConstantPerChannelQuantity[0] = 0.0;
                _fragmentConstantPerChannelQuantity[1] = 0.0;
                _fragmentConstantPerChannelQuantity[2] = 0.0;
                _fragmentConstantPerChannelQuantity[3] = 0.0;

            case PerChannel:
                var levelsBasePC:Int = (_levels > 0) ? _levels : 1;

                var bitsNeeded:Int = Std.int(Math.ceil(Math.log(Math.max(1, levelsBasePC)) / Math.log(2)));
                if (bitsNeeded < 1) bitsNeeded = 1;

                bitsR = bitsG = bitsB = bitsNeeded;

                var levelsR = (bitsR > 0) ? (1 << bitsR) : 1;
                var levelsG = (bitsG > 0) ? (1 << bitsG) : 1;
                var levelsB = (bitsB > 0) ? (1 << bitsB) : 1;

                var kRInt = (levelsR - 1 > 0) ? (levelsR - 1) : 1;
                var kGInt = (levelsG - 1 > 0) ? (levelsG - 1) : 1;
                var kBInt = (levelsB - 1 > 0) ? (levelsB - 1) : 1;

                _kLuma = 1.0;
                _modeFlag = 1.0;

                _fragmentConstantPacked[1] = _kLuma;     // unused in this mode
                _fragmentConstantPacked[2] = _modeFlag;  // 1
                _fragmentConstantPacked[3] = 0.0;

                _fragmentConstantPerChannelQuantity[0] = cast(kRInt, Float);
                _fragmentConstantPerChannelQuantity[1] = cast(kGInt, Float);
                _fragmentConstantPerChannelQuantity[2] = cast(kBInt, Float);
                _fragmentConstantPerChannelQuantity[3] = 0.0;
        }
    }

    public function get_levels():Int return _levels;
    public function set_levels(v:Int):Int {
        _levels = (v > 0) ? v : 1;
        updateKVec();
        return _levels;
    }

    public function get_quantizeMode():QuantizeMode return _quantizeMode;
    public function set_quantizeMode(m:QuantizeMode):QuantizeMode {
        _quantizeMode = m;
        updateKVec();
        return _quantizeMode;
    }

    // -------------------------------------------------
    // Called by ShaderPipeline before each draw
    // -------------------------------------------------
    public override function prepair(?options:{
        ?backbufferWidth:UInt,
        ?backbufferHeight:UInt,
    }) {
        final w = cast(options?.backbufferWidth, Float);
        final h = cast(options?.backbufferHeight, Float);

        // fc0.xy = [W/n, H/n]
        _fragmentConstantSize[0] = (w > 0) ? (w / _ditheringSize) : 0.0;
        _fragmentConstantSize[1] = (h > 0) ? (h / _ditheringSize) : 0.0;
        _fragmentConstantSize[2] = 0.0;
        _fragmentConstantSize[3] = 0.0;
    }

    public override function dispose(engine:IRendererEngine) {
        Debugger.log("BayerishDitheringShaderPart dispose");

        if (_ditheringTextureMask != null) removeTexture(_ditheringTextureMask);
        _ditheringTextureMask = null;

        super.dispose(engine);
    }

    public override function isTheSame(part:ShaderPart):Bool {
        return Std.isOfType(part, BayerishDitheringShaderPart);
    }
}