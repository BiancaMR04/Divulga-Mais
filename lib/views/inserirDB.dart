import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InserirMenusExemploScreen extends StatelessWidget {
  const InserirMenusExemploScreen({super.key});

  Future<void> inserirMenus() async {
    final menus = [
      {
        "nome": "Áreas",
        "tipo": "submenu",
        "ativo": true,
        "ordem": 1,
        "icone": "book",
        "campoFiltro": "areaId",
        "valorFiltro": null,
        "submenus": [
          {
            "nome": "Saúde",
            "tipo": "artigos",
            "ativo": true,
            "ordem": 1,
            "campoFiltro": "areaId",
            "valorFiltro": "saude",
          },
          {
            "nome": "Biológicas",
            "tipo": "artigos",
            "ativo": true,
            "ordem": 2,
            "campoFiltro": "areaId",
            "valorFiltro": "biologicas",
          },
          {
            "nome": "Fisiológicas",
            "tipo": "artigos",
            "ativo": true,
            "ordem": 3,
            "campoFiltro": "areaId",
            "valorFiltro": "fisiologicas",
          },
        ],
      },
      {
        "nome": "PPGs",
        "tipo": "submenu",
        "ativo": true,
        "ordem": 2,
        "icone": "school",
        "campoFiltro": "ppgId",
        "valorFiltro": null,
        "submenus": [
          {
            "nome": "Bioquímica",
            "tipo": "submenu",
            "ativo": true,
            "ordem": 1,
            "campoFiltro": "ppgId",
            "valorFiltro": "ppg_bioquimica",
            "submenus": [
              {
                "nome": "Biotecnologia",
                "tipo": "artigos",
                "ativo": true,
                "ordem": 1,
                "campoFiltro": "linhasPesquisaIds",
                "valorFiltro": "linha_bioqui_biotecnologia",
              },
              {
                "nome": "Química Medicinal",
                "tipo": "artigos",
                "ativo": true,
                "ordem": 2,
                "campoFiltro": "linhasPesquisaIds",
                "valorFiltro": "linha_quimica_medicinal",
              },
            ],
          },
        ],
      },
      {
        "nome": "Assuntos",
        "tipo": "submenu",
        "ativo": true,
        "ordem": 3,
        "icone": "library_books",
        "campoFiltro": "assuntoId",
        "valorFiltro": null,
        "submenus": [
          {
            "nome": "Psicologia",
            "tipo": "artigos",
            "ativo": true,
            "ordem": 1,
            "campoFiltro": "assuntoId",
            "valorFiltro": "psicologia",
          },
          {
            "nome": "Biotecnologia",
            "tipo": "artigos",
            "ativo": true,
            "ordem": 2,
            "campoFiltro": "assuntoId",
            "valorFiltro": "biotecnologia",
          },
          {
            "nome": "Medicamentos",
            "tipo": "artigos",
            "ativo": true,
            "ordem": 3,
            "campoFiltro": "assuntoId",
            "valorFiltro": "medicamentos",
          },
        ],
      },
      {
        "nome": "Grupos de Pesquisa",
        "tipo": "submenu",
        "ativo": true,
        "ordem": 4,
        "icone": "groups",
        "campoFiltro": "grupoPesquisaId",
        "valorFiltro": null,
        "submenus": [
          {
            "nome": "Mindfulness",
            "tipo": "artigos",
            "ativo": true,
            "ordem": 1,
            "campoFiltro": "grupoPesquisaId",
            "valorFiltro": "grupo_mindfulness",
          },
          {
            "nome": "Neurocom",
            "tipo": "artigos",
            "ativo": true,
            "ordem": 2,
            "campoFiltro": "grupoPesquisaId",
            "valorFiltro": "grupo_neurocom",
          },
          {
            "nome": "BioquiLab",
            "tipo": "artigos",
            "ativo": true,
            "ordem": 3,
            "campoFiltro": "grupoPesquisaId",
            "valorFiltro": "grupo_bioqui_lab",
          },
        ],
      },
    ];

    final menusRef = FirebaseFirestore.instance.collection('menus');

    // Função recursiva para inserir submenus
    Future<void> addSubmenus(CollectionReference ref, List<Map<String, dynamic>> submenus) async {
      for (final sub in submenus) {
        final subCopy = Map<String, dynamic>.from(sub);
        final nestedSub = subCopy.remove('submenus');
        final docRef = await ref.add(subCopy);
        if (nestedSub != null && nestedSub is List) {
          await addSubmenus(docRef.collection('submenus'), nestedSub.cast<Map<String, dynamic>>());
        }
      }
    }

    // Adiciona os menus principais
    for (final menu in menus) {
      final menuCopy = Map<String, dynamic>.from(menu);
      final submenus = menuCopy.remove('submenus');
      final docRef = await menusRef.add(menuCopy);
      if (submenus != null && submenus is List) {
        await addSubmenus(docRef.collection('submenus'), submenus.cast<Map<String, dynamic>>());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inserir Menus de Exemplo"),
        backgroundColor: const Color(0xFF0F6E58),
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F6E58),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () async {
            await inserirMenus();
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Menus e submenus inseridos com sucesso! 🎉")),
            );
          },
          child: const Text(
            "Inserir Menus de Exemplo",
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
