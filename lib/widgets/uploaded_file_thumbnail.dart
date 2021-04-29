export 'package:uploadgram/widgets/platform_specific/uploaded_file_thumbnail/common.dart';

export 'package:uploadgram/widgets/platform_specific/uploaded_file_thumbnail/android.dart'
    if (dart.library.html) 'package:uploadgram/widgets/platform_specific/uploaded_file_thumbnail/web.dart';
