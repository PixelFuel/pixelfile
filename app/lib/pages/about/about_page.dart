import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/version_provider.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/pixelfile_logo.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage();

  @override
  Widget build(BuildContext context) {
    final version = context.ref.watch(versionProvider);

    return Scaffold(
      appBar: basicPixelFileAppbar(t.aboutPage.title),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: [
          const SizedBox(height: 20),
          const PixelFileLogo(withText: true),
          const SizedBox(height: 4),
          const Text(
            'PixelFile',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          version.maybeWhen(
            data: (value) => Text(
              '版本 $value',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 32),
          const Text(
            '济南像素引擎人工智能有限公司',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          const Text(
            'Content enriches life!',
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            '内容让生活更有料',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: () async {
                await launchUrl(Uri.parse('https://www.pixelfuel.cn'));
              },
              child: const Text('www.pixelfuel.cn'),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
