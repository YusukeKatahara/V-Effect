import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class HomeSkeletonBody extends StatelessWidget {
  final Widget titleBar;

  const HomeSkeletonBody({super.key, required this.titleBar});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          titleBar,
          const Spacer(),
          Center(
            child: Container(
              width: MediaQuery.sizeOf(context).width * 0.72,
              height: MediaQuery.sizeOf(context).height * 0.6,
              decoration: BoxDecoration(
                color: AppColors.grey10,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
