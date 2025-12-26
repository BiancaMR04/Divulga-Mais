import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:divulgapampa/homescreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:divulgapampa/services/storage_media_service.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  User? _user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _userData;
  bool _loading = true;
  bool _deleting = false;

  bool _isPasswordUser(User user) {
    return user.providerData.any((p) => p.providerId == 'password');
  }

  Future<bool> _reauthenticateWithCurrentPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    if (!_isPasswordUser(user) || (user.email ?? '').toString().trim().isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sua conta não usa senha (login por provedor). Para trocar a senha, use “Esqueci minha senha” no login.',
          ),
        ),
      );
      return false;
    }

    final passCtrl = TextEditingController();
    String? passErro;
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Confirmar senha'),
              content: TextField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Senha atual',
                  errorText: passErro,
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => obscure = !obscure),
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                onChanged: (_) {
                  if (passErro != null) setDialogState(() => passErro = null);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
                  onPressed: () {
                    if (passCtrl.text.isEmpty) {
                      setDialogState(() => passErro = 'Informe sua senha atual.');
                      return;
                    }
                    Navigator.pop(dialogCtx, true);
                  },
                  child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return false;

    await _showBlockingProgress('Confirmando…');
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!.trim(),
        password: passCtrl.text,
      );
      await user.reauthenticateWithCredential(credential);
      if (!mounted) return false;
      Navigator.pop(context); // fecha progresso
      return true;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return false;
      Navigator.pop(context); // fecha progresso
      String msg = e.message ?? 'Falha ao confirmar senha.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Senha atual incorreta.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return false;
    } catch (e) {
      if (!mounted) return false;
      Navigator.pop(context); // fecha progresso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao confirmar senha: $e')),
      );
      return false;
    }
  }

  Future<void> _promptReLogin(String message) async {
    if (!mounted) return;

    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Login necessário'),
        content: Text(
          '$message\n\n'
          'Por segurança, faça login novamente e tente de novo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Agora não'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ir para login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (go == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    }
  }

  Future<void> _showBlockingProgress(String title) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: const SizedBox(
          height: 90,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<void> _changeEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentEmail = (user.email ?? (_userData?['email'] ?? '')).toString().trim();
    final emailCtrl = TextEditingController(text: currentEmail);
    String? emailErro;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Alterar e-mail'),
              content: TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Novo e-mail',
                  errorText: emailErro,
                ),
                onChanged: (_) {
                  if (emailErro != null) setDialogState(() => emailErro = null);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
                  onPressed: () {
                    final newEmail = emailCtrl.text.trim();
                    if (newEmail.isEmpty || !newEmail.contains('@')) {
                      setDialogState(() => emailErro = 'Informe um e-mail válido.');
                      return;
                    }
                    Navigator.pop(dialogCtx, true);
                  },
                  child: const Text('Salvar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;
    final newEmail = emailCtrl.text.trim();

    if (newEmail.toLowerCase() == currentEmail.toLowerCase()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este já é o seu e-mail atual.')),
      );
      return;
    }

    await _showBlockingProgress('Atualizando e-mail…');
    try {
      // Fluxo recomendado pelo plugin: envia e-mail de verificação e só troca após confirmar.
      await user.verifyBeforeUpdateEmail(newEmail);

      if (!mounted) return;
      Navigator.pop(context); // fecha progresso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enviamos um e-mail para confirmar a troca para "$newEmail". Após confirmar, o e-mail será atualizado.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // fecha progresso

      if (e.code == 'requires-recent-login') {
        final ok = await _reauthenticateWithCurrentPassword();
        if (!ok) return;
        await _showBlockingProgress('Atualizando e-mail…');
        try {
          await user.verifyBeforeUpdateEmail(newEmail);
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Enviamos um e-mail para confirmar a troca para "$newEmail". Após confirmar, o e-mail será atualizado.',
              ),
            ),
          );
        } catch (e2) {
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar e-mail: $e2')),
          );
        }
        return;
      }

      String msg = e.message ?? 'Erro ao atualizar e-mail.';
      if (e.code == 'email-already-in-use') {
        msg = 'Este e-mail já está em uso.';
      } else if (e.code == 'invalid-email') {
        msg = 'E-mail inválido.';
      } else if (e.code == 'operation-not-allowed') {
        msg = 'Operação não permitida. Verifique configurações do Auth.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // fecha progresso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar e-mail: $e')),
      );
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_isPasswordUser(user) || (user.email ?? '').toString().trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sua conta não usa senha (login por provedor). Para trocar a senha, use “Esqueci minha senha” no login.',
          ),
        ),
      );
      return;
    }

    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? currentErro;
    String? newErro;
    String? confirmErro;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Alterar senha'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentCtrl,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Senha atual',
                        errorText: currentErro,
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                          icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      onChanged: (_) {
                        if (currentErro != null) setDialogState(() => currentErro = null);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Nova senha',
                        errorText: newErro,
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                          icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      onChanged: (_) {
                        if (newErro != null) setDialogState(() => newErro = null);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirmar nova senha',
                        errorText: confirmErro,
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                          icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      onChanged: (_) {
                        if (confirmErro != null) setDialogState(() => confirmErro = null);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
                  onPressed: () {
                    final currentPass = currentCtrl.text;
                    final newPass = newCtrl.text;
                    final confirmPass = confirmCtrl.text;

                    bool hasError = false;
                    if (currentPass.isEmpty) {
                      currentErro = 'Informe sua senha atual.';
                      hasError = true;
                    }
                    if (newPass.trim().isEmpty) {
                      newErro = 'Informe a nova senha.';
                      hasError = true;
                    } else if (newPass.trim().length < 6) {
                      newErro = 'A senha deve ter pelo menos 6 caracteres.';
                      hasError = true;
                    }
                    if (confirmPass.isEmpty) {
                      confirmErro = 'Confirme a nova senha.';
                      hasError = true;
                    } else if (confirmPass != newPass) {
                      confirmErro = 'As senhas não conferem.';
                      hasError = true;
                    }

                    if (hasError) {
                      setDialogState(() {});
                      return;
                    }
                    Navigator.pop(dialogCtx, true);
                  },
                  child: const Text('Salvar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    await _showBlockingProgress('Atualizando senha…');
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!.trim(),
        password: currentCtrl.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newCtrl.text.trim());

      if (!mounted) return;
      Navigator.pop(context); // fecha progresso
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha atualizada com sucesso.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // fecha progresso

      String msg = e.message ?? 'Erro ao atualizar senha.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Senha atual incorreta.';
      } else if (e.code == 'weak-password') {
        msg = 'Senha fraca. Use uma senha mais forte.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // fecha progresso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar senha: $e')),
      );
    }
  }

  Future<void> _carregarUsuario() async {
    if (_user == null) return;
    try {
      _user = FirebaseAuth.instance.currentUser;

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        final authEmail = (_user?.email ?? '').toString().trim();
        final firestoreEmail = (data['email'] ?? '').toString().trim();

        // Se o Auth mudou (ex: confirmação de troca de e-mail), sincroniza o Firestore.
        if (authEmail.isNotEmpty && authEmail != firestoreEmail) {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(_user!.uid)
              .update({'email': authEmail}).catchError((_) {});
        }

        setState(() {
          _userData = {
            ...data,
            if (authEmail.isNotEmpty) 'email': authEmail,
          };
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar perfil: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
  }

  bool _canSelfDelete() {
    final tipo = (_userData?['tipo'] ?? '').toString().trim().toLowerCase();
    // Permite comum e líder. Bloqueia superuser/admin para evitar perder acesso administrativo.
    if (tipo == 'superuser' || tipo == 'admin') return false;
    return true;
  }

  Future<void> _deleteOwnContentRecursive(String uid) async {
    final firestore = FirebaseFirestore.instance;

    while (true) {
      final snap = await firestore
          .collection('artigos')
          .where('autorUid', isEqualTo: uid)
          .limit(200)
          .get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        final data = doc.data();
        final imagemStoragePath = (data['imagemStoragePath'] ?? '').toString().trim();
        final videoStoragePath = (data['videoStoragePath'] ?? '').toString().trim();

        if (imagemStoragePath.isNotEmpty) {
          await StorageMediaService.deleteIfExists(imagemStoragePath);
        }
        if (videoStoragePath.isNotEmpty) {
          await StorageMediaService.deleteIfExists(videoStoragePath);
        }

        await doc.reference.delete();
      }
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_canSelfDelete()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esta conta não pode ser excluída por aqui.')),
        );
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Esta ação é permanente.\n\n'
          '• Sua conta será excluída do login\n'
          '• Seu perfil será removido\n'
          '• Suas publicações e mídias (imagem/vídeo) serão removidas\n',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _deleting = true);
    try {
      // 1) Limpa dados do usuário (publicações + mídias)
      await _deleteOwnContentRecursive(user.uid);

      // Remove o perfil no Firestore (se existir)
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .delete()
          .catchError((_) {});

      // Exclui a conta do Firebase Auth
      await user.delete();

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta excluída com sucesso.')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Por segurança, faça login novamente para excluir a conta.',
            ),
          ),
        );
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Erro ao excluir conta')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir conta: $e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
  }

  @override
  Widget build(BuildContext context) {
    const double topOffset = 160;

    return Scaffold(
      backgroundColor: const Color(0xFF0F6E58),
      bottomNavigationBar: CustomNavBar(
        tipoUsuario: (_userData?['tipo'] ?? '').toString(),
        selected: NavDestination.profile,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/home.png', fit: BoxFit.cover),
            ),

            // conteúdo
            Positioned.fill(
              top: topOffset,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _userData == null
                        ? const Center(
                            child: Text(
                              "Nenhum dado encontrado.",
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 20),
                                CircleAvatar(
                                  radius: 45,
                                  backgroundColor:
                                      const Color(0xFF0F6E58).withOpacity(0.1),
                                  child: Icon(
                                    PhosphorIcons.userCircle(),
                                    size: 70,
                                    color: const Color(0xFF0F6E58),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _userData?['nome'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F6E58),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _userData?['email'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F6E58)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _userData?['tipo']?.toString().toUpperCase() ??
                                        '',
                                    style: const TextStyle(
                                      color: Color(0xFF0F6E58),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                const Divider(),
                                const SizedBox(height: 10),

                                ElevatedButton.icon(
                                  onPressed: _changeEmail,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F6E58),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.email_outlined, color: Colors.white),
                                  label: const Text(
                                    'Alterar e-mail',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  onPressed: _changePassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F6E58),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.lock_outline, color: Colors.white),
                                  label: const Text(
                                    'Alterar senha',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // botão logout
                                ElevatedButton.icon(
                                  onPressed: _logout,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F6E58),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.logout,
                                      color: Colors.white),
                                  label: const Text(
                                    'Sair da conta',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),

                                if (_canSelfDelete()) ...[
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: _deleting ? null : _deleteAccount,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 20),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: _deleting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.delete_forever,
                                            color: Colors.white),
                                    label: Text(
                                      _deleting ? 'Excluindo...' : 'Excluir conta',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
              ),
            ),

            // topo verde
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const HomeScreen()),
  );
},

                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Meu Perfil",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
