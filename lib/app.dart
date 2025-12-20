
/*import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../widgets/menu_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

IconData _iconeFromString(String nome) {
  switch (nome) {
    case 'school':
      return PhosphorIcons.graduationCap();
    case 'groups':
      return PhosphorIcons.usersThree();
    case 'book':
      return PhosphorIcons.bookBookmark();
    case 'library_books':
      return PhosphorIcons.books();
    case 'info':
      return PhosphorIcons.info();
    case 'phone':
      return PhosphorIcons.phone();
    default:
      return PhosphorIcons.squaresFour();
  }
}

  Color _corPorIndice(int i) {
    final cores = [
      Color.fromARGB(255, 181, 107, 130), // vermelho
      Color.fromARGB(255, 152, 200, 173), // verde
      Color.fromARGB(255, 224, 164, 143), // laranja
      Color.fromARGB(255, 175, 181, 236), // azul
      Color.fromARGB(255, 236, 208, 139), // amarelo
      Color.fromARGB(255, 220, 159, 211), // rosa
    ];
    return cores[i % cores.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F6E58),
      bottomNavigationBar: BottomAppBar(
  color: const Color.fromARGB(255, 238, 238, 238),
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // ou .center para mais juntos
      children: [
        IconButton(
          onPressed: () {},
          icon: Icon(
            PhosphorIcons.house(),
            color: Color.fromARGB(255, 255, 118, 72), // ícone ativo (laranja)
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(
            PhosphorIcons.user(),
            color: Colors.grey, // ícone inativo
          ),
        ),
      ],
    ),
  ),
),




        body: SafeArea(
  child: Stack(
    children: [
      // ✅ IMAGEM DE FUNDO
      Positioned.fill(
        child: Image.asset(
          'assets/home.png',
          fit: BoxFit.cover, // ou .contain/.fill conforme o efeito desejado
        ),
      ),
  Stack(
  children: [
    // CONTAINER BRANCO (ajustado mais pra baixo)
    Positioned.fill(
      top: 160, // Aumentado
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.only(top: 80), // Espaço maior para o conteúdo
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Categorias',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('menus')
                    .where('ativo', isEqualTo: true)
                    .orderBy('ordem')
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Nenhum menu encontrado.'));
                  }

                  final menus = snapshot.data!.docs;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: List.generate(menus.length, (index) {
                        final menu = menus[index];
                        return MenuCard(
                          titulo: menu['nome'],
                          icone: _iconeFromString(menu['icone']),
                          cor: _corPorIndice(index),
                          onTap: () {},
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),

    // CABEÇALHO + BUSCA (ajustado mais pra baixo também)
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 50), // Aumentado
          const Text(
            'Divulga Pampa',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 95), // Mais espaço antes da busca
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Pesquise por...',
                      border: InputBorder.none,
                      icon: Icon(Icons.search),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.filter_list),
              ),
            ],
          ),
        ],
      ),
    ),
  ],
),

    ],
        ),
        ),
    );
  }
}
*/