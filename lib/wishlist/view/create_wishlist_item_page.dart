import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/wishlist_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/wishlist/cubit/cubit.dart';
import 'package:intellispendiq/wishlist/widgets/widgets.dart';

/// A full page for capturing a new wishlist item — photos included at
/// creation time, not bolted on afterward. Replaces the old bottom
/// sheet: a handful of stacked text fields in a sheet had no room to
/// give the name, the price, and a photo their own visual weight, and
/// there was nowhere to attach a photo until the item already existed.
class CreateWishlistItemPage extends StatelessWidget {
  const CreateWishlistItemPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const CreateWishlistItemPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A fresh cubit off the globally-provided repository, not the
    // calling page's — a full-page route pushed onto the Navigator
    // sits outside that page's local BlocProvider, so it couldn't read
    // it anyway. Nothing here needs shared state: `create()` only
    // needs the repository, and the list page's own subscription picks
    // up the new item reactively once this pops.
    return BlocProvider(
      create: (context) => WishlistCubit(context.read<WishlistRepository>()),
      child: const _CreateWishlistItemView(),
    );
  }
}

class _CreateWishlistItemView extends StatefulWidget {
  const _CreateWishlistItemView();

  @override
  State<_CreateWishlistItemView> createState() =>
      _CreateWishlistItemViewState();
}

class _CreateWishlistItemViewState extends State<_CreateWishlistItemView> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _seenAtController = TextEditingController();
  final _urlController = TextEditingController();
  final _noteController = TextEditingController();
  final _photoPaths = <String>[];
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _seenAtController.dispose();
    _urlController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    await context.read<WishlistCubit>().create(
      name: _nameController.text,
      estimatedPrice: _priceController.text,
      seenAt: _seenAtController.text,
      productUrl: _urlController.text,
      note: _noteController.text,
      photoPaths: _photoPaths,
    );
    if (!mounted) return;
    final state = context.read<WishlistCubit>().state;
    if (state.status == WishlistStatus.invalid) {
      setState(() {
        _saving = false;
        _error = state.errorMessage;
      });
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add to wishlist')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.x2,
          Space.gutter,
          Space.x3,
        ),
        children: [
          StagedPhotoStrip(
            paths: _photoPaths,
            onAdd: (path) => setState(() => _photoPaths.add(path)),
            onRemove: (path) => setState(() => _photoPaths.remove(path)),
          ),
          const SizedBox(height: Space.x3),
          AppTextField(
            controller: _nameController,
            label: 'What do you want?',
            hint: 'New cooking pots',
            errorText: _error,
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: Space.x2),
          AmountField(
            controller: _priceController,
            label: 'Estimated price (optional)',
          ),
          const SizedBox(height: Space.sectionGap),
          SectionHeader(title: 'Details', subtitle: 'All optional'),
          AppCard(
            child: Column(
              children: [
                AppTextField(
                  controller: _seenAtController,
                  label: 'Where you saw it',
                  hint: 'Shoprite, an online store…',
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: Space.x2),
                AppTextField(
                  controller: _urlController,
                  label: 'Product link',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: Space.x2),
                TextField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTypography.body(color: colors.onSurface),
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.x3),
          AppButton.primary(
            label: _saving ? 'Adding…' : 'Add to wishlist',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
