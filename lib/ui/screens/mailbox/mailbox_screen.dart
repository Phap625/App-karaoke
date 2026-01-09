import 'package:flutter/material.dart';
import 'notifications_tab.dart';
import 'messages_tap.dart';

class MailboxScreen extends StatelessWidget {
  const MailboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF00CC);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            "Hộp thư",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryColor,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Thông báo"),
              Tab(text: "Nhắn tin"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            NotificationsTab(),
            MessagesTab(),
          ],
        ),
      ),
    );
  }
}