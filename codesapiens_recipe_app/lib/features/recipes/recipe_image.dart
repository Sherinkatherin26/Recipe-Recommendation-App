import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class RecipeImage extends StatelessWidget {
  const RecipeImage({super.key, required this.src, this.fit});
  final String src;
  final BoxFit? fit;

  bool get _isNetwork => src.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isNetwork) {
      return CachedNetworkImage(
        imageUrl: src,
        fit: fit ?? BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey.shade200),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
    return Image.asset(src, fit: fit ?? BoxFit.cover);
  }
}





