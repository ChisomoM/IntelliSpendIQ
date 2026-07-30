import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/custom_sender_repository.dart';
import 'package:intellispendiq/domain/parsers/parser_registry.dart';
import 'package:intellispendiq/senders/cubit/cubit.dart';
import 'package:intellispendiq/senders/widgets/widgets.dart';

class CustomSendersPage extends StatelessWidget {
  const CustomSendersPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const CustomSendersPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CustomSendersCubit(
        context.read<CustomSenderRepository>(),
        context.read<ParserRegistry>(),
      )..loadUnawaited(),
      child: const CustomSendersView(),
    );
  }
}

class CustomSendersView extends StatelessWidget {
  const CustomSendersView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message senders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add sender',
            onPressed: () => CustomSenderEditorSheet.show(context),
          ),
        ],
      ),
      body: BlocBuilder<CustomSendersCubit, CustomSendersState>(
        builder: (context, state) {
          if (state.isEmpty) return const NoCustomSendersYet();
          if (state.status == CustomSendersStatus.initial ||
              state.status == CustomSendersStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.separated(
            itemCount: state.senders.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                CustomSenderTile(sender: state.senders[index]),
          );
        },
      ),
    );
  }
}
