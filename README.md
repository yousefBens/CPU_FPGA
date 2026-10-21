# CPU_FPGA — Conception d'un CPU 16 bits en VHDL

## 1. Présentation du projet

Ce projet consiste à concevoir, développer, simuler et implémenter un processeur (CPU) 16 bits entièrement en VHDL sur une carte FPGA **Digilent Cmod A7-35T**.

L'objectif est de construire un véritable processeur simple à partir de zéro afin de comprendre son architecture interne, son fonctionnement et son implémentation matérielle.

Le projet sera réalisé progressivement, depuis la définition de l'architecture jusqu'à l'exécution de programmes sur le FPGA.

### Objectifs pédagogiques

- Comprendre l'architecture interne d'un processeur.
- Concevoir une architecture CPU personnalisée.
- Définir un jeu d'instructions (ISA).
- Comprendre le codage binaire des instructions.
- Développer des modules matériels en VHDL.
- Concevoir une unité arithmétique et logique (ALU).
- Concevoir un banc de registres (Register File).
- Développer une unité de contrôle (Control Unit).
- Concevoir les mémoires RAM et ROM en VHDL.
- Comprendre le fonctionnement des bus internes.
- Comprendre le cycle d'exécution des instructions.
- Développer des testbenches VHDL.
- Simuler et vérifier chaque module.
- Synthétiser et implémenter le CPU sur FPGA.
- Exécuter des programmes réels sur le processeur.

---

## 2. Matériel et environnement de développement

### 2.1 Carte FPGA

| Caractéristique | Description |
|-----------------|-------------|
| Carte | Digilent Cmod A7-35T |
| FPGA | AMD/Xilinx Artix-7 |
| Référence FPGA | XC7A35T-1CPG236C |
| Langage HDL | VHDL |
| Outil de développement | AMD Vivado |
| Simulation | Vivado Simulator (XSim) |
| Horloge de la carte | 12 MHz |
| Interface de programmation | USB-JTAG |
| Interfaces de test | LED, boutons, UART, GPIO |

### 2.2 Contraintes de développement

Le CPU sera développé à partir de modules VHDL personnalisés.

Aucune IP matérielle préconçue de Vivado ne sera utilisée pour construire les blocs fonctionnels du processeur.

Cela concerne notamment :

- ALU
- Register File
- Control Unit
- Program Counter
- Instruction Register
- Instruction Decoder
- RAM
- ROM
- Bus internes
- Gestion des flags

Les mémoires RAM et ROM seront décrites directement en VHDL.

**Remarque :** même si les mémoires sont décrites en VHDL, Vivado pourra les implémenter physiquement dans les ressources internes du FPGA, notamment les Block RAM (BRAM). L'objectif est de ne pas utiliser les IP de mémoire préconçues.

---

# 3. Architecture générale du CPU

## 3.1 Architecture retenue

Le processeur utilisera une architecture simple :

| Paramètre | Choix initial |
|-----------|---------------|
| Architecture | Harvard |
| Taille des données | 16 bits |
| Taille des registres | 16 bits |
| Nombre de registres généraux | 8 |
| Taille des instructions | 16 bits |
| Architecture d'exécution | Multi-cycle |
| Pipeline | Non |
| Unité de calcul | ALU 16 bits |
| Mémoire programme | ROM personnalisée |
| Mémoire données | RAM personnalisée |
| Unité de contrôle | FSM |
| Langage | VHDL |

Ces choix constituent la base initiale du projet. Certains paramètres pourront être ajustés pendant la phase de spécification.

## 3.2 Architecture Harvard

L'architecture Harvard utilise deux mémoires distinctes :

- Instruction Memory : contient les instructions du programme.
- Data Memory : contient les données manipulées par le CPU.

Schéma simplifié :

```text
                   +----------------------+
                   |         CPU          |
                   |                      |
                   |  +----------------+  |
                   |  | Program Counter|  |
                   |  +-------+--------+  |
                   |          |           |
                   +----------|-----------+
                              |
                              v
                    +-------------------+
                    | Instruction ROM   |
                    |    (VHDL)         |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | Instruction       |
                    | Decoder           |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | Control Unit      |
                    | FSM               |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | Register File     |
                    | 8 x 16 bits       |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | ALU 16 bits       |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | Data RAM          |
                    |    (VHDL)         |
                    +-------------------+
```

Ce schéma est une représentation fonctionnelle simplifiée. Le datapath détaillé sera conçu pendant la Phase 1.

---

# 4. Blocs matériels à développer

Tous les blocs suivants seront développés en VHDL.

## 4.1 Program Counter (PC)

Le Program Counter contient l'adresse de la prochaine instruction à exécuter.

Fonctions :

- Initialisation après reset.
- Incrémentation du PC.
- Chargement d'une nouvelle adresse.
- Gestion des sauts et branchements.

Exemple :

```text
PC = 0
PC = 1
PC = 2

JMP 10

PC = 10
```

## 4.2 Instruction Memory (ROM)

Mémoire contenant le programme à exécuter.

Fonctions :

- Stocker les instructions binaires.
- Recevoir une adresse depuis le PC.
- Fournir l'instruction correspondante.

La ROM sera entièrement décrite en VHDL.

Exemple :

```text
Adresse    Instruction

0x0000     LDI R1, 5
0x0001     LDI R2, 3
0x0002     ADD R1, R2
0x0003     HALT
```

Les instructions seront stockées sous forme binaire.

## 4.3 Instruction Register (IR)

Registre contenant l'instruction en cours d'exécution.

Fonctions :

- Capturer l'instruction provenant de la ROM.
- Conserver l'instruction pendant son exécution.
- Fournir les champs au décodeur.

## 4.4 Instruction Decoder

Le décodeur analyse les différents champs de l'instruction.

Exemple :

```text
Instruction 16 bits

+--------+-------+-------+--------+
| OPCODE |  Rd   |  Rs   |  IMM   |
+--------+-------+-------+--------+
```

Il permet d'identifier :

- L'opération demandée.
- Les registres concernés.
- Les valeurs immédiates.
- Les informations nécessaires à l'unité de contrôle.

Le format exact sera défini pendant la Phase 1.

## 4.5 Register File

Le CPU disposera de 8 registres généraux de 16 bits.

```text
R0 : 16 bits
R1 : 16 bits
R2 : 16 bits
R3 : 16 bits
R4 : 16 bits
R5 : 16 bits
R6 : 16 bits
R7 : 16 bits
```

Fonctions :

- Lire les valeurs de deux registres.
- Écrire un résultat dans un registre.
- Fournir les opérandes à l'ALU.

## 4.6 Arithmetic Logic Unit (ALU)

L'ALU réalise les opérations arithmétiques et logiques.

Opérations envisagées :

| Opération | Description |
|-----------|-------------|
| ADD | Addition |
| SUB | Soustraction |
| AND | ET logique |
| OR | OU logique |
| XOR | OU exclusif |
| CMP | Comparaison |

L'ALU travaillera sur des données de 16 bits.

## 4.7 Flags Register

Le registre FLAGS contient des informations sur le résultat des opérations.

Flags envisagés :

| Flag | Description |
|------|-------------|
| Z | Zero |
| C | Carry |
| N | Negative |

Ces flags permettront notamment de réaliser des branchements conditionnels.

## 4.8 Data Memory (RAM)

La RAM contiendra les données utilisées par les programmes.

Fonctions :

- Lecture d'une donnée à une adresse.
- Écriture d'une donnée à une adresse.
- Stockage temporaire des résultats.

La RAM sera conçue directement en VHDL.

Les modalités de lecture et d'écriture seront définies avant l'implémentation.

## 4.9 Control Unit

L'unité de contrôle coordonne l'ensemble des blocs du CPU.

Elle sera développée sous forme d'une machine à états finis (FSM).

États envisagés :

```text
FETCH
  |
  v
DECODE
  |
  v
EXECUTE
  |
  v
MEMORY
  |
  v
WRITEBACK
  |
  v
FETCH
```

Selon l'instruction, certains états pourront être ignorés.

---

# 5. Jeu d'instructions (ISA)

Le CPU disposera d'un jeu d'instructions personnalisé.

## 5.1 Instructions envisagées

| Instruction | Fonction |
|-------------|----------|
| NOP | Aucune opération |
| ADD | Addition |
| SUB | Soustraction |
| AND | ET logique |
| OR | OU logique |
| XOR | OU exclusif |
| MOV | Copie entre registres |
| LDI | Chargement d'une constante |
| LOAD | Lecture RAM |
| STORE | Écriture RAM |
| CMP | Comparaison |
| JMP | Saut inconditionnel |
| JZ | Saut si flag Z actif |
| HALT | Arrêt de l'exécution |

Cette liste sera validée pendant la Phase 1.

## 5.2 Exemple de programme

Programme permettant d'additionner deux nombres :

```asm
LDI R1, 5
LDI R2, 3
ADD R1, R2
HALT
```

Résultat attendu :

```text
R1 = 8
```

L'encodage binaire de ce programme sera défini après validation de l'ISA.

---

# 6. Organisation du projet

Structure envisagée :

```text
CPU_FPGA/
|
|-- README.md
|-- .gitignore
|
|-- docs/
|   |-- architecture/
|   |   |-- CPU_SPEC.md
|   |   |-- ISA.md
|   |   |-- DATAPATH.md
|   |
|   |-- verification/
|       |-- TEST_PLAN.md
|
|-- rtl/
|   |
|   |-- cpu/
|   |   |-- cpu_top.vhd
|   |   |-- control_unit.vhd
|   |   |-- instruction_decoder.vhd
|   |
|   |-- datapath/
|   |   |-- alu.vhd
|   |   |-- register_file.vhd
|   |   |-- program_counter.vhd
|   |   |-- instruction_register.vhd
|   |   |-- flags_register.vhd
|   |
|   |-- memory/
|       |-- instruction_rom.vhd
|       |-- data_ram.vhd
|
|-- tb/
|   |-- tb_alu.vhd
|   |-- tb_register_file.vhd
|   |-- tb_program_counter.vhd
|   |-- tb_instruction_rom.vhd
|   |-- tb_data_ram.vhd
|   |-- tb_control_unit.vhd
|   |-- tb_cpu_top.vhd
|
|-- programs/
|   |-- test_add.asm
|   |-- test_memory.asm
|   |-- test_branch.asm
|
|-- constraints/
|   |-- cmod_a7_35t.xdc
|
|-- scripts/
|
|-- results/
|
|-- CPU_FPGA.xpr
```

Les dossiers et fichiers seront créés progressivement.

---

# 7. Plan de développement

Le projet sera organisé en 7 phases.

## PHASE 1 — Architecture et spécifications

**Objectif : définir précisément le fonctionnement du CPU.**

### Tâches

- [ ] 1.1 Comprendre le principe d'une ISA.
- [ ] 1.2 Définir la taille des données et des registres.
- [ ] 1.3 Définir les instructions supportées.
- [ ] 1.4 Définir le format binaire des instructions.
- [ ] 1.5 Définir l'organisation de la ROM et de la RAM.
- [ ] 1.6 Définir les flags et les branchements.
- [ ] 1.7 Concevoir le datapath général.
- [ ] 1.8 Définir le fonctionnement de la FSM.
- [ ] 1.9 Rédiger les spécifications finales.

### Livrables

```text
docs/architecture/CPU_SPEC.md
docs/architecture/ISA.md
docs/architecture/DATAPATH.md
```

### Validation

La phase sera considérée comme terminée lorsque :

- Chaque instruction possède un comportement défini.
- Le format binaire des instructions est connu.
- Les registres et mémoires sont spécifiés.
- Le datapath est documenté.
- Le cycle d'exécution est défini.
- L'architecture ne présente pas d'incohérences connues.

---

## PHASE 2 — Développement des blocs élémentaires

**Objectif : développer et tester les composants fondamentaux.**

### Tâches

- [ ] Développer l'ALU.
- [ ] Développer le Register File.
- [ ] Développer le Program Counter.
- [ ] Développer l'Instruction Register.
- [ ] Développer le Flags Register.
- [ ] Développer la ROM en VHDL.
- [ ] Développer la RAM en VHDL.

### Validation

Chaque module devra disposer d'un testbench.

Tests envisagés :

- Opérations arithmétiques.
- Opérations logiques.
- Lecture et écriture des registres.
- Incrémentation et chargement du PC.
- Lecture des instructions depuis la ROM.
- Lecture et écriture de la RAM.
- Gestion du reset.

---

## PHASE 3 — Développement de l'unité de contrôle

**Objectif : concevoir le mécanisme d'exécution des instructions.**

### Tâches

- [ ] Développer l'Instruction Decoder.
- [ ] Définir les signaux de contrôle.
- [ ] Développer la FSM.
- [ ] Implémenter les états FETCH, DECODE et EXECUTE.
- [ ] Implémenter les accès mémoire.
- [ ] Implémenter WRITEBACK.
- [ ] Implémenter les sauts conditionnels.

### Validation

Simuler la séquence d'exécution de plusieurs instructions.

Vérifier :

- La transition entre les états.
- Le décodage des instructions.
- Les signaux de contrôle.
- La mise à jour du PC.
- La gestion des flags.

---

## PHASE 4 — Intégration complète du CPU

**Objectif : connecter tous les blocs pour obtenir un CPU fonctionnel.**

### Tâches

- [ ] Développer cpu_top.vhd.
- [ ] Connecter le datapath.
- [ ] Connecter la Control Unit.
- [ ] Connecter la ROM.
- [ ] Connecter la RAM.
- [ ] Connecter les signaux d'horloge et de reset.
- [ ] Vérifier les bus internes.

### Validation

Exécuter un premier programme complet en simulation.

Exemple :

```asm
LDI R1, 5
LDI R2, 3
ADD R1, R2
HALT
```

Résultat attendu :

```text
R1 = 8
CPU_STATE = HALT
```

---

## PHASE 5 — Vérification fonctionnelle

**Objectif : vérifier le comportement du CPU avec plusieurs programmes.**

### Tâches

- [ ] Tester les opérations arithmétiques.
- [ ] Tester les opérations logiques.
- [ ] Tester les accès RAM.
- [ ] Tester les branchements.
- [ ] Tester les boucles.
- [ ] Tester les flags.
- [ ] Tester les cas limites.
- [ ] Développer des tests automatisés.

### Validation

Comparer les résultats du CPU avec les résultats attendus.

Les tests devront être reproductibles.

---

## PHASE 6 — Implémentation sur FPGA

**Objectif : faire fonctionner le CPU sur la Cmod A7-35T.**

### Tâches

- [ ] Définir le top-level FPGA.
- [ ] Configurer l'horloge de 12 MHz.
- [ ] Configurer le reset.
- [ ] Ajouter les contraintes XDC.
- [ ] Lancer la synthèse.
- [ ] Analyser l'utilisation des ressources FPGA.
- [ ] Lancer l'implémentation.
- [ ] Vérifier les contraintes temporelles.
- [ ] Générer le bitstream.
- [ ] Programmer la carte.

### Validation

Vérifier que :

- Le bitstream est généré.
- Les contraintes temporelles sont respectées.
- Le CPU démarre après reset.
- Le programme stocké en ROM s'exécute.
- Les résultats correspondent aux simulations.

---

## PHASE 7 — Tests réels et améliorations

**Objectif : observer et exploiter le CPU sur la carte FPGA.**

### Tâches

- [ ] Exécuter un programme de démonstration.
- [ ] Afficher un résultat sur les LED.
- [ ] Ajouter une interface UART personnalisée.
- [ ] Transmettre des informations du CPU vers un PC.
- [ ] Tester plusieurs programmes.
- [ ] Mesurer les performances.
- [ ] Analyser les ressources utilisées.
- [ ] Documenter les résultats.

### Améliorations possibles

- Ajout de nouvelles instructions.
- Ajout d'opérations de décalage.
- Ajout d'un Stack Pointer.
- Gestion des interruptions.
- Développement d'un assembleur Python.
- Chargement de programmes depuis un PC.
- Optimisation du nombre de cycles par instruction.
- Introduction d'un pipeline.

---

# 8. Méthode de travail

Le projet sera développé progressivement.

Pour chaque module :

1. Comprendre son rôle dans le CPU.
2. Définir son comportement.
3. Définir ses entrées et sorties.
4. Dessiner son architecture logique.
5. Écrire le code VHDL.
6. Développer un testbench.
7. Exécuter la simulation.
8. Analyser les chronogrammes.
9. Corriger les éventuelles erreurs.
10. Valider le module avant intégration.

Aucun module ne sera considéré comme terminé sans validation fonctionnelle.

---

# 9. Critères de réussite du projet

Le projet sera considéré comme réussi lorsque :

- Le CPU est entièrement décrit en VHDL.
- La RAM et la ROM sont décrites en VHDL.
- Le CPU comprend et exécute son ISA.
- Les programmes sont exécutés correctement.
- Les différents modules disposent de testbenches.
- Le CPU fonctionne sur la Cmod A7-35T.
- Les résultats sont observables depuis la carte ou un PC.
- Les performances et les ressources FPGA sont documentées.

---

# 10. État d'avancement

| Phase | Description | État |
|-------|-------------|------|
| 1 | Architecture et spécifications | En cours |
| 2 | Blocs élémentaires | À faire |
| 3 | Control Unit | À faire |
| 4 | Intégration CPU | À faire |
| 5 | Vérification fonctionnelle | À faire |
| 6 | Implémentation FPGA | À faire |
| 7 | Tests et améliorations | À faire |

---

# 11. Références

Documentation officielle :

- [Digilent Cmod A7](https://digilent.com/reference/programmable-logic/cmod-a7/start)
- [AMD Vivado Design Suite](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
- [AMD 7 Series FPGA Documentation](https://docs.amd.com/)

---

## Conclusion

Ce projet a pour objectif de comprendre et maîtriser la conception d'un processeur numérique, depuis la définition de son architecture jusqu'à son fonctionnement réel sur FPGA.

L'ensemble du développement sera réalisé progressivement en VHDL, avec une attention particulière portée à la compréhension des architectures matérielles, à la simulation et à la vérification fonctionnelle.
