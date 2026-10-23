# CPU_FPGA — Conception d'un processeur 8 bits en VHDL sur FPGA

> **Projet pédagogique de conception d'un CPU à partir de blocs RTL personnalisés, intégrés avec Vivado IP Integrator, programmé en assembleur et observé en simulation et avec une ILA.**
>
> **État du projet :** exécution d'un programme `LDI → ADD → STORE → HALT` vérifiée en simulation, avec `RAM[0x10] = 0x1E` pour `10 + 20`. Les autres instructions et l'exécution sur FPGA physique doivent être validées séparément.

## Sommaire

1. [Objectifs](#1-objectifs)
2. [Caractéristiques et architecture](#2-caractéristiques-et-architecture)
3. [Architecture matérielle : datapath et contrôle](#3-architecture-matérielle--datapath-et-contrôle)
4. [Modules VHDL](#4-modules-vhdl)
5. [Organisation des mémoires et registres](#5-organisation-des-mémoires-et-registres)
6. [ISA : jeu d'instructions](#6-isa--jeu-dinstructions)
7. [Encodage et décodage des instructions](#7-encodage-et-décodage-des-instructions)
8. [ALU et flags](#8-alu-et-flags)
9. [Control Unit et FSM](#9-control-unit-et-fsm)
10. [Chemins de données et signaux de contrôle](#10-chemins-de-données-et-signaux-de-contrôle)
11. [Assemblage du CPU dans Vivado Block Design](#11-assemblage-du-cpu-dans-vivado-block-design)
12. [Écriture de programmes assembleur](#12-écriture-de-programmes-assembleur)
13. [Assembleur Python et génération de program.mem](#13-assembleur-python-et-génération-de-programmem)
14. [ROM initialisée par fichier](#14-rom-initialisée-par-fichier)
15. [Simulation et validation](#15-simulation-et-validation)
16. [Debug sur FPGA avec ILA](#16-debug-sur-fpga-avec-ila)
17. [Problèmes fréquents](#17-problèmes-fréquents)
18. [Tests recommandés](#18-tests-recommandés)
19. [Limites et évolutions](#19-limites-et-évolutions)
20. [Glossaire](#20-glossaire)

---

## 1. Objectifs

Ce projet vise à comprendre le fonctionnement d'un processeur en **construisant réellement ses éléments internes** en VHDL, plutôt qu'en utilisant un cœur CPU prêt à l'emploi.

Le travail couvre :

- la définition d'une **ISA** (*Instruction Set Architecture*) ;
- la création d'une **ALU** 8 bits ;
- la conception d'un **banc de registres** ;
- l'organisation d'une mémoire programme et d'une mémoire de données ;
- la réalisation d'un **Program Counter** et d'un **Instruction Register** ;
- le décodage des instructions ;
- la conception d'une **unité de contrôle à machine d'états** ;
- la construction d'un **datapath** avec des multiplexeurs ;
- l'intégration de modules RTL dans **Vivado Block Design** ;
- l'écriture de programmes dans un **assembleur personnalisé** ;
- la traduction de l'assembleur en code machine avec Python ;
- l'observation de l'exécution dans le simulateur et, à terme, sur FPGA avec une **ILA**.

**Idée centrale :** le matériel (VHDL) définit *comment* les instructions fonctionnent ; le logiciel assembleur définit *quelles* instructions le CPU exécute.

---

## 2. Caractéristiques et architecture

| Élément | Choix actuel |
|---|---|
| Type | CPU pédagogique 8 bits |
| Architecture mémoire | Harvard : programme et données séparés |
| Taille d'une instruction | 16 bits |
| Taille des données | 8 bits |
| Registres généraux | 8 × 8 bits, R0 à R7 |
| Program Counter (PC) | 8 bits |
| Mémoire programme | 256 mots × 16 bits |
| Mémoire données | 256 mots × 8 bits |
| ALU | ADD, SUB, AND, OR, XOR, NOT, SHL, SHR |
| Flags | Z, C, N, V |
| Jeu d'instructions | 16 opcodes |
| Exécution | Multicycle, sans pipeline |
| Langage matériel | VHDL |
| Outils | AMD/Xilinx Vivado, IP Integrator, simulateur XSim |
| Programme utilisateur | Assembleur personnalisé (`.asm`) |
| Image ROM | Fichier texte hexadécimal (`.mem`) |

### 2.1 Architecture Harvard

Deux espaces de stockage indépendants :

```text
                         +----------------------+
       PC[7:0] --------->| PROGRAM MEMORY       |
                         | 256 x 16 bits         |
                         +-----------+----------+
                                     |
                               instruction[15:0]
                                     |
                                     v
                            +-----------------+
                            | INSTRUCTION REG  |
                            +--------+--------+
                                     |
                                     v
                            +-----------------+
                            | DECODER +        |
                            | CONTROL UNIT    |
                            +--------+--------+
                                     |
                         signaux de commande
                                     |
              +----------------------+--------------------+
              |                                           |
              v                                           v
      +----------------+                           +--------------+
      | REGISTER FILE  |<--- WRITEBACK MUX <-------| DATA RAM     |
      | R0 ... R7      |          ^                | 256 x 8 bits |
      +------+---------+          |                +--------------+
             |                    |
          A, B                    |
             v                    |
       +------------+             |
       | ALU 8 bits |-------------+
       +------+-----+
              |
              v
       +----------------+
       | FLAGS REGISTER |
       +----------------+
```

**Attention :** le schéma est fonctionnel, pas un schéma de câblage exhaustif. Les adresses, sélections de mux, horloges, resets et signaux d'activation sont détaillés plus loin.

### 2.2 Exécution multicycle

Une instruction est traitée en plusieurs cycles d'horloge : lecture ROM, chargement IR, décodage, exécution, éventuellement accès RAM, puis écriture du résultat.

Contrairement à un CPU pipeline, plusieurs instructions ne sont pas volontairement exécutées en parallèle. Les sorties des blocs combinatoires peuvent toutefois évoluer en permanence.

---

## 3. Architecture matérielle : datapath et contrôle

### 3.1 Datapath

Le **datapath** est l'ensemble des blocs qui **transportent, sélectionnent, calculent et stockent** les données :

- `register_file` : source et destination des opérandes ;
- `alu` : calcul arithmétique/logique ;
- `writeback_mux` : sélection de la donnée écrite dans le registre ;
- `data_ram` : stockage de données ;
- `program_counter` : stockage de l'adresse programme ;
- `instruction_register` : mémorisation de l'instruction ;
- `flags_register` : stockage de l'état arithmétique.

Le **datapath n'est pas uniquement l'ALU** : il comprend aussi les chemins et les multiplexeurs reliant les composants.

### 3.2 Control Unit

La `control_unit` n'effectue pas l'addition elle-même. Elle **commande les autres modules** en activant les bons signaux au bon cycle :

- `pc_enable` : incrémenter le PC ;
- `pc_load` : charger une nouvelle adresse dans le PC ;
- `ir_enable` : capturer une instruction ;
- `reg_write_enable` : écrire dans un registre ;
- `reg_write_sel` : sélectionner la source du writeback ;
- `ram_read_enable` / `ram_write_enable` : accéder à la RAM ;
- `alu_op` : choisir l'opération de l'ALU ;
- `flags_write_enable` : enregistrer les flags ;
- `halted` : signaler l'arrêt.

### 3.3 Différence entre bloc RTL, IP et Block Design

- **Module RTL** : entité VHDL (`entity` + `architecture`).
- **IP empaquetée** : module présenté dans le catalogue IP de Vivado avec ses métadonnées et paramètres.
- **Module Reference** : ajout direct d'un module RTL au Block Design, sans empaquetage IP complet.
- **Block Design** : assemblage graphique de ces composants et de leurs connexions.
- **HDL Wrapper** : entité VHDL générée par Vivado pour instancier le Block Design.

L'assemblage des IP dans le Block Design **constitue le datapath et son système de contrôle**, à condition que les connexions et les timings soient corrects.

---

## 4. Modules VHDL

### 4.1 `alu.vhd`

**Rôle :** calcul combinatoire sur deux opérandes 8 bits.

| Port | Direction | Largeur | Rôle |
|---|---|---:|---|
| `A` | Entrée | 8 | Premier opérande |
| `B` | Entrée | 8 | Second opérande |
| `ALU_OP` | Entrée | 3 | Opération demandée |
| `RESULT` | Sortie | 8 | Résultat |
| `Z` | Sortie | 1 | Résultat nul |
| `C` | Sortie | 1 | Retenue / emprunt |
| `N` | Sortie | 1 | Bit de signe |
| `V` | Sortie | 1 | Overflow signé |

L'ALU est **combinatoire** : il n'y a pas de `Clk`. Le résultat change lorsque A, B ou ALU_OP changent. Ce n'est pas une preuve qu'une instruction a été *validée* : la Control Unit doit encore autoriser l'écriture dans les registres.

### 4.2 `register_file.vhd`

**Rôle :** huit registres R0–R7 de 8 bits.

- `read_addr_a[2:0]` → sélection de la première source ;
- `read_data_a[7:0]` → valeur lue sur le port A ;
- `read_addr_b[2:0]` → sélection de la deuxième source ;
- `read_data_b[7:0]` → valeur lue sur le port B ;
- `write_addr[2:0]` → registre destination ;
- `write_data[7:0]` → donnée à écrire ;
- `write_enable` → autorisation d'écriture ;
- `Clk`, `rst` → horloge et reset.

**Lectures asynchrones**, écriture **synchrone** au front montant.

```vhdl
read_data_a <= registers(to_integer(unsigned(read_addr_a)));
read_data_b <= registers(to_integer(unsigned(read_addr_b)));
```

L'écriture ne se produit que si `write_enable = '1'` au front montant.

### 4.3 `program_counter.vhd`

Le PC contient l'adresse de la prochaine instruction à lire dans la ROM.

- `pc_out[7:0]` → adresse courante ;
- `pc_enable` → `PC <= PC + 1` ;
- `pc_load` → `PC <= pc_load_data` ;
- `pc_load_data[7:0]` → adresse d'un `JMP` ou `JZ` ;
- `rst` → PC = 0.

**Priorité du VHDL actuel :** reset > `pc_load` > `pc_enable`.

### 4.4 `program_memory.vhd`

ROM de **256 instructions de 16 bits**, lecture synchrone :

```vhdl
if rising_edge(Clk) then
    data_reg <= ROM(to_integer(unsigned(addr)));
end if;
```

La ROM est initialisée à partir de `program.mem`. Le PC fournit `addr[7:0]` et `data_out[15:0]` fournit l'instruction lue après le front d'horloge.

### 4.5 `instruction_register.vhd`

Mémorise une instruction 16 bits pour que son contenu reste stable pendant les états DECODE, EXECUTE, MEMORY et WRITEBACK.

```vhdl
if rising_edge(Clk) then
    if rst = '1' then
        Instruction_reg <= (others => '0');
    elsif ir_enable = '1' then
        Instruction_reg <= Instruction_in;
    end if;
end if;
```

### 4.6 `instruction_decoder.vhd`

Décompose les champs de l'instruction :

```vhdl
opcode    <= Instruction_in(15 downto 12);
rd        <= Instruction_in(11 downto 9);
rs        <= Instruction_in(8 downto 6);
immediate <= Instruction_in(7 downto 0);
jump_addr <= Instruction_in(7 downto 0);
```

Le décodeur est combinatoire : il n'exécute pas l'instruction, il expose simplement ses champs.

### 4.7 `control_unit.vhd`

FSM synchrone qui transforme `opcode`, `flag_z` et l'état courant en commandes matérielles. Voir [section 9](#9-control-unit-et-fsm).

### 4.8 `flags_register.vhd`

Stocke les quatre indicateurs `Z`, `C`, `N`, `V` au front montant lorsque `flags_write_enable = 1`.

L'ALU calcule les flags combinatoirement ; **le Flags Register mémorise** leurs valeurs afin que `JZ` utilise le résultat de la dernière instruction ayant mis à jour les flags.

### 4.9 `data_ram.vhd`

RAM **256 × 8 bits** avec écriture et lecture synchrones :

```vhdl
if rising_edge(Clk) then
    if write_enable = '1' then
        RAM(to_integer(unsigned(addr))) <= write_data;
    elsif read_enable = '1' then
        read_data_reg <= RAM(to_integer(unsigned(addr)));
    end if;
end if;
```

Si lecture et écriture sont simultanément activées, **l'écriture est prioritaire**. La RAM n'a pas de reset global afin de préserver la possibilité d'inférence en Block RAM.

### 4.10 `writeback_mux.vhd`

Sélectionne la valeur écrite dans le Register File :

| `reg_write_sel` | Source | Instructions typiques |
|---|---|---|
| `00` | `ALU.RESULT` | ADD, SUB, AND, OR, XOR, NOT, SHL, SHR |
| `01` | `immediate` | LDI |
| `10` | `data_ram.read_data` | LOAD |
| `11` | Réservé | — |

**Interface de principe** : trois entrées 8 bits, une sélection 2 bits et une sortie 8 bits. Les noms exacts des ports dépendent du `writeback_mux.vhd` présent dans le projet.

Exemple de logique :

```vhdl
with reg_write_sel select
    write_data <= alu_result when "00",
                  immediate  when "01",
                  ram_data   when "10",
                  (others => '0') when others;
```

---

## 5. Organisation des mémoires et registres

### 5.1 Trois stockages à ne pas confondre

| Stockage | Adresse | Contenu | Utilisé par |
|---|---|---|---|
| **Register File** | 3 bits (R0–R7) | 8 registres × 8 bits | ALU, LDI, LOAD, STORE |
| **Data RAM** | 8 bits (`0x00`–`0xFF`) | 256 octets | LOAD, STORE |
| **Program Memory** | 8 bits (`PC`) | 256 instructions × 16 bits | FETCH |

Les trois espaces sont **indépendants**. `R0`, `RAM[0]` et `ROM[0]` sont trois emplacements différents.

### 5.2 Exemple : registre versus RAM

```asm
LDI R0, 50
STORE R0, 0x00
LDI R0, 100
HALT
```

État final :

```text
R0        = 100 (0x64)
RAM[0x00] =  50 (0x32)
```

### 5.3 Sélection d'un registre

| Nom | Adresse binaire | Valeur |
|---|---|---:|
| R0 | `000` | 0 |
| R1 | `001` | 1 |
| R2 | `010` | 2 |
| R3 | `011` | 3 |
| R4 | `100` | 4 |
| R5 | `101` | 5 |
| R6 | `110` | 6 |
| R7 | `111` | 7 |

### 5.4 Adressage RAM direct

L'instruction `STORE R1, 0x20` signifie :

- lire la valeur de R1 ;
- mettre `addr = 0x20` sur la RAM ;
- mettre la valeur de R1 sur `write_data` ;
- activer `ram_write_enable` ;
- au front montant, écrire `RAM[32]`.

`0x20` est **hexadécimal** et vaut 32 en décimal. Le CPU actuel n'a pas d'adressage indirect par registre.

---

## 6. ISA : jeu d'instructions

**ISA** signifie *Instruction Set Architecture*. C'est le contrat entre le programme assembleur et le matériel. Une instruction n'est valide que si son **encodage**, son **décodage** et son **exécution matérielle** sont cohérents.

### 6.1 Table officielle des opcodes

| Opcode (binaire) | Hex | Mnémotechnique | Syntaxe | Effet |
|---|---:|---|---|---|
| `0000` | 0 | `NOP` | `NOP` | Ne rien faire |
| `0001` | 1 | `ADD` | `ADD Rd, Rs` | `Rd ← Rd + Rs` |
| `0010` | 2 | `SUB` | `SUB Rd, Rs` | `Rd ← Rd - Rs` |
| `0011` | 3 | `AND` | `AND Rd, Rs` | `Rd ← Rd AND Rs` |
| `0100` | 4 | `OR` | `OR Rd, Rs` | `Rd ← Rd OR Rs` |
| `0101` | 5 | `XOR` | `XOR Rd, Rs` | `Rd ← Rd XOR Rs` |
| `0110` | 6 | `NOT` | `NOT Rd` | `Rd ← NOT Rd` |
| `0111` | 7 | `SHL` | `SHL Rd` | `Rd ← Rd << 1` |
| `1000` | 8 | `SHR` | `SHR Rd` | `Rd ← Rd >> 1` logique |
| `1001` | 9 | `LDI` | `LDI Rd, imm8` | `Rd ← imm8` |
| `1010` | A | `LOAD` | `LOAD Rd, addr8` | `Rd ← RAM[addr8]` |
| `1011` | B | `STORE` | `STORE Rd, addr8` | `RAM[addr8] ← Rd` |
| `1100` | C | `JMP` | `JMP addr8` | `PC ← addr8` |
| `1101` | D | `JZ` | `JZ addr8` | Saut si `Z = 1` |
| `1110` | E | `CMP` | `CMP Rd, Rs` | Flags de `Rd - Rs`, sans écriture de Rd |
| `1111` | F | `HALT` | `HALT` | Arrêt de la FSM |

### 6.2 Détails des instructions

**LDI** — charge une constante :

```asm
LDI R0, 10       ; R0 = 10
LDI R1, 0x14     ; R1 = 20
```

**ADD** — addition sur 8 bits :

```asm
ADD R0, R1       ; R0 = (R0 + R1) modulo 256
```

**SUB** — soustraction sur 8 bits :

```asm
SUB R0, R1       ; R0 = (R0 - R1) modulo 256
```

**AND / OR / XOR** — opérations logiques bit à bit :

```asm
AND R0, R1       ; masque
OR  R0, R1       ; mise à 1 de bits
XOR R0, R1       ; inversion sélective
```

**NOT** — inversion de tous les bits :

```asm
NOT R0           ; 0x0F devient 0xF0
```

**SHL / SHR** — décalage logique d'un bit :

```asm
SHL R0           ; 5 devient 10 (sans débordement)
SHR R0           ; 10 devient 5
```

**LOAD / STORE** — transfert entre RAM et registres :

```asm
STORE R0, 0x20   ; RAM[32] = R0
LOAD  R2, 0x20   ; R2 = RAM[32]
```

**CMP** — compare sans modifier les registres :

```asm
CMP R0, R1       ; flags de R0 - R1
```

**JMP** — saute sans condition :

```asm
JMP LOOP
```

**JZ** — saute si le flag Z vaut 1 :

```asm
CMP R0, R1
JZ EQUAL
```

**NOP** — avance sans opération utile :

```asm
NOP
```

**HALT** — arrêt jusqu'au reset :

```asm
HALT
```

### 6.3 Restrictions actuelles

- Les valeurs sont stockées sur **8 bits** ; les résultats arithmétiques sont tronqués à 8 bits.
- Les adresses de saut et de RAM sont sur **8 bits**.
- `JZ` est le seul saut conditionnel.
- Pas de `MOV`, `MUL`, `DIV`, `CALL`, `RET`, `JNZ`, `GPIO`, `UART` dans cette ISA.
- L'ALU travaille sur des **registres**, pas directement sur deux cases RAM.
- Le CPU n'a pas encore de pile, d'interruptions ni de périphériques adressables.

---

## 7. Encodage et décodage des instructions

### 7.1 Format général

Une instruction occupe **16 bits** :

```text
15          12 11        9 8         6 5             0
+-------------+------------+-----------+---------------+
| OPCODE (4)  | Rd (3)     | Rs (3)    | réservé (6)   |
+-------------+------------+-----------+---------------+
```

Le format change selon le type d'instruction. Les champs peuvent **se chevaucher** dans le décodeur car ils ne sont pas utilisés simultanément.

### 7.2 Format R — ALU et CMP

```text
[15:12] opcode | [11:9] Rd | [8:6] Rs | [5:0] 000000
```

Formule :

```python
instruction = (opcode << 12) | (rd << 9) | (rs << 6)
```

**Exemple : `ADD R0, R1`**

```text
opcode = 0001
Rd     = 000
Rs     = 001
reste  = 000000

0001 000 001 000000 = 0x1040
```

**Exemple : `CMP R0, R2`**

```text
opcode = 1110
Rd     = 000
Rs     = 010
reste  = 000000

1110 000 010 000000 = 0xE080
```

Pour `NOT`, `SHL`, `SHR`, le champ Rs est ignoré et encodé à zéro.

### 7.3 Format I — LDI, LOAD, STORE

```text
[15:12] opcode | [11:9] Rd | [8] 0 | [7:0] immediate / adresse
```

Formule :

```python
instruction = (opcode << 12) | (rd << 9) | immediate
```

**Exemple : `LDI R1, 20`**

```text
opcode = 1001
Rd     = 001
bit 8  = 0
imm8   = 00010100

1001 001 0 00010100 = 0x9214
```

**Exemple : `STORE R0, 0x10`** → `0xB010`.

### 7.4 Format J — JMP et JZ

```text
[15:12] opcode | [11:8] 0000 | [7:0] adresse
```

Formule :

```python
instruction = (opcode << 12) | address
```

**Exemple : `JZ 0x08`** → `0xD008`.

`NOP` → `0x0000` ; `HALT` → `0xF000`.

### 7.5 Comment le matériel décode

Pour `0x9214` :

```text
Instruction Register = 0x9214
              |
              v
     INSTRUCTION DECODER
              |
              +-- opcode    = 1001   → LDI
              +-- rd        = 001    → R1
              +-- immediate = 0x14   → 20
              |
              v
         CONTROL UNIT
              |
              +-- reg_write_sel = 01  (immédiat)
              +-- reg_write_enable = 1 au WRITEBACK
              |
              v
      REGISTER FILE[R1] = 20
```

### 7.6 Chevauchement `Rs` / `immediate`

Le décodeur existant utilise `Rs = Instruction_in(8 downto 6)` et `immediate = Instruction_in(7 downto 0)`. Les bits 7 et 6 se recouvrent : **c'est acceptable ici** car :

- une instruction ALU utilise `Rd` et `Rs`, mais pas `immediate` ;
- `LDI`, `LOAD`, `STORE` utilisent `Rd` et `immediate`, mais pas `Rs` ;
- `JMP`, `JZ` utilisent seulement l'adresse de saut.

Le matériel doit ignorer les champs non pertinents selon l'opcode.

---

## 8. ALU et flags

### 8.1 Correspondance ALU_OP

| `ALU_OP` | Opération | Comportement |
|---|---|---|
| `000` | ADD | A + B |
| `001` | SUB | A - B |
| `010` | AND | A AND B |
| `011` | OR | A OR B |
| `100` | XOR | A XOR B |
| `101` | NOT | NOT A |
| `110` | SHL | A décalé à gauche |
| `111` | SHR | A décalé à droite |

`CMP` réutilise **SUB** (`ALU_OP = 001`) sans activer `reg_write_enable`.

### 8.2 Flags

| Flag | Signification | Exemple |
|---|---|---|
| Z | `RESULT = 0` | `10 - 10 = 0` → Z = 1 |
| C | Carry ADD / emprunt SUB | `250 + 20` → C = 1 |
| N | `RESULT(7)` | `10 - 20 = 0xF6` → N = 1 |
| V | Overflow signé ADD/SUB | `127 + 1` → V = 1 |

**Attention à la convention C :** dans le VHDL de ce projet, pour SUB, `C = 1` signifie **emprunt** (`A < B`). Ce n'est pas la convention « no borrow » de certains processeurs.

**Attention aux shifts :** le VHDL actuel met `C = 0` pour SHL/SHR ; il ne conserve pas le bit décalé. `V = 0` pour les opérations logiques et les shifts. Ce sont des choix d'implémentation, pas des propriétés universelles des CPU.

### 8.3 Flags et branches

```asm
LDI R0, 10
LDI R1, 10
CMP R0, R1
JZ EQUAL
```

La séquence produit `Z = 1`, donc `JZ` charge l'adresse de `EQUAL` dans le PC.

`LDI`, `LOAD`, `STORE`, `JMP` et `JZ` ne doivent pas modifier les flags dans la Control Unit actuelle. Une opération ALU **entre** `CMP` et `JZ` pourrait remplacer Z : il faut en tenir compte lors de l'écriture du programme.

---

## 9. Control Unit et FSM

### 9.1 États utilisés

La Control Unit actuelle possède les états :

```text
FETCH_ROM
   |
   v
FETCH_WAIT
   |
   v
FETCH_IR
   |
   v
DECODE
   |
   v
EXECUTE -----> HALT -------------> ST_HALTED
   |
   +----------> ALU/LDI ----------> WRITEBACK ----+
   |                                              |
   +----------> LOAD/STORE -------> MEMORY        |
   |                                |             |
   |                         LOAD: MEMORY_WAIT    |
   |                                |             |
   |                                v             |
   |                            WRITEBACK --------+
   |                                              |
   +----------> JMP/JZ/NOP/CMP --------------------+
                                                  |
                                                  v
                                               FETCH_ROM
```

### 9.2 Pourquoi plusieurs états FETCH ?

La ROM est **synchrone** : son `data_out` n'est actualisé qu'après un front montant. Le registre d'instruction doit capturer une valeur **déjà valide**.

La séquence `FETCH_ROM → FETCH_WAIT → FETCH_IR` ménage ce délai et évite les erreurs de lecture, notamment après une modification du PC par JMP/JZ.

### 9.3 Tableau des actions principales

| Instruction | EXECUTE | MEMORY | WRITEBACK |
|---|---|---|---|
| NOP | `pc_enable=1` | — | — |
| ADD/SUB/AND/OR/XOR/NOT/SHL/SHR | `flags_write_enable=1` | — | `reg_write_enable=1`, `reg_write_sel=00`, `pc_enable=1` |
| CMP | `flags_write_enable=1`, `pc_enable=1` | — | — |
| LDI | Préparer la valeur immédiate | — | `reg_write_enable=1`, `reg_write_sel=01`, `pc_enable=1` |
| LOAD | Préparer l'adresse | `ram_read_enable=1` | Après `MEMORY_WAIT` : `reg_write_enable=1`, `reg_write_sel=10`, `pc_enable=1` |
| STORE | Préparer adresse et donnée | `ram_write_enable=1`, `pc_enable=1` | — |
| JMP | `pc_load=1` | — | — |
| JZ | `pc_load=1` si Z, sinon `pc_enable=1` | — | — |
| HALT | Aller à `ST_HALTED` | — | — |

### 9.4 Pourquoi le PC ne change pas à chaque cycle ?

Le PC représente l'adresse de l'instruction courante pendant ses différents états. Il avance seulement lorsque la Control Unit a terminé cette instruction, ou reçoit une nouvelle adresse lors d'un saut.

### 9.5 Pourquoi un `MEMORY_WAIT` ?

La Data RAM possède une lecture synchrone : `read_data` devient valide après le front où `read_enable = 1`. L'état d'attente permet de laisser la donnée se stabiliser avant l'écriture dans le Register File.

### 9.6 Timing : sorties combinatoires, écritures synchrones

Les signaux de contrôle issus de la FSM sont **combinatoires** en fonction de l'état et de l'opcode. Les registres et RAM les échantillonnent au **front montant**. Un signal `write_enable=1` pendant un état ne signifie donc pas que la donnée a déjà été écrite : l'écriture a lieu au front suivant.

---

## 10. Chemins de données et signaux de contrôle

### 10.1 Exemple `LDI R1, 20`

```text
IR → Decoder → rd=R1, immediate=0x14
                     |
Control Unit : reg_write_sel=01, reg_write_enable=1
                     |
Writeback MUX : sélection immediate
                     |
Register File : write_addr=001, write_data=0x14
                     |
              front montant
                     v
                   R1=20
```

### 10.2 Exemple `ADD R0, R1`

```text
IR → Decoder : Rd=000, Rs=001
       |                 |
       v                 v
RegFile read A=R0    RegFile read B=R1
       |                 |
       +------ ALU ------+
             ALU_OP=000
                  |
            RESULT=R0+R1
                  |
           Writeback MUX=00
                  |
        RegFile write_addr=R0
                  |
             R0 ← RESULT
```

Les flags sont capturés pendant EXECUTE, le résultat est écrit dans R0 pendant WRITEBACK.

### 10.3 Exemple `STORE R0, 0x10`

```text
Decoder Rd=R0 ----------> RegFile read_data_a
Decoder immediate=0x10 -> RAM.addr
RegFile read_data_a ----> RAM.write_data
Control Unit -----------> RAM.write_enable

Au front montant : RAM[0x10] ← R0
```

### 10.4 Exemple `LOAD R2, 0x10`

```text
Decoder immediate=0x10 -> RAM.addr
Control Unit -----------> RAM.read_enable
RAM.read_data ----------> Writeback MUX (sel=10)
Decoder Rd=R2 ----------> RegFile.write_addr
Control Unit -----------> RegFile.write_enable

Au front WRITEBACK : R2 ← RAM[0x10]
```

### 10.5 Exemple `CMP` + `JZ`

```text
CMP R0,R1 : ALU SUB → flags_register.Z
                                |
JZ LABEL : Control Unit lit flag_z
                                |
                  Z=1 → pc_load=1
                  Z=0 → pc_enable=1
```

---

## 11. Assemblage du CPU dans Vivado Block Design

### 11.1 Préparation

1. Ouvrir `CPU_FPGA.xpr` dans Vivado.
2. Vérifier que les fichiers `.vhd` sont dans **Design Sources**.
3. Créer un Block Design, par exemple `design_1` ou `cpu_system_bd`.
4. Ajouter les blocs via **Add Module** ou les IP empaquetées via **Add IP**.
5. Ajouter les blocs un à un, puis connecter leurs interfaces.
6. Utiliser **Validate Design** et corriger les incompatibilités.

### 11.2 Blocs à intégrer

- `program_counter`
- `program_memory`
- `instruction_register`
- `instruction_decoder`
- `control_unit`
- `register_file`
- `alu`
- `flags_register`
- `data_ram`
- `writeback_mux`
- éventuellement `ila` pour le debug FPGA.

### 11.3 Connexions : instruction et PC

| Source | Destination | Justification |
|---|---|---|
| `program_counter.pc_out` | `program_memory.addr` | Le PC adresse la ROM |
| `program_memory.data_out` | `instruction_register.Instruction_in` | Instruction lue |
| `control_unit.ir_enable` | `instruction_register.ir_enable` | Autoriser la capture |
| `instruction_register.Instruction_out` | `instruction_decoder.Instruction_in` | Décoder l'instruction |
| `instruction_decoder.opcode` | `control_unit.opcode` | Choix de l'instruction |
| `control_unit.pc_enable` | `program_counter.pc_enable` | PC + 1 |
| `control_unit.pc_load` | `program_counter.pc_load` | Saut |
| `instruction_decoder.jump_addr` | `program_counter.pc_load_data` | Adresse de saut |

### 11.4 Connexions : registres et ALU

| Source | Destination | Justification |
|---|---|---|
| `instruction_decoder.rd` | `register_file.read_addr_a` | Lire Rd |
| `instruction_decoder.rs` | `register_file.read_addr_b` | Lire Rs |
| `instruction_decoder.rd` | `register_file.write_addr` | Écrire Rd |
| `register_file.read_data_a` | `alu.A` | Premier opérande |
| `register_file.read_data_b` | `alu.B` | Second opérande |
| `control_unit.alu_op` | `alu.ALU_OP` | Sélection de l'opération |
| `control_unit.reg_write_enable` | `register_file.write_enable` | Autoriser l'écriture |

### 11.5 Connexions : flags

| Source | Destination |
|---|---|
| `alu.Z` | `flags_register.z_in` |
| `alu.C` | `flags_register.c_in` |
| `alu.N` | `flags_register.n_in` |
| `alu.V` | `flags_register.v_in` |
| `control_unit.flags_write_enable` | `flags_register.write_enable` |
| `flags_register.z_out` | `control_unit.flag_z` |

Les sorties `c_out`, `n_out`, `v_out` peuvent être observées en simulation/ILA même si elles ne pilotent pas encore de branches.

### 11.6 Connexions : Data RAM

| Source | Destination |
|---|---|
| `instruction_decoder.immediate` | `data_ram.addr` |
| `register_file.read_data_a` | `data_ram.write_data` |
| `control_unit.ram_read_enable` | `data_ram.read_enable` |
| `control_unit.ram_write_enable` | `data_ram.write_enable` |
| `data_ram.read_data` | Entrée RAM du `writeback_mux` |

### 11.7 Connexions : Writeback MUX

| Source | Destination |
|---|---|
| `alu.RESULT` | Entrée ALU du mux |
| `instruction_decoder.immediate` | Entrée immédiat du mux |
| `data_ram.read_data` | Entrée RAM du mux |
| `control_unit.reg_write_sel` | Sélection du mux |
| Sortie du mux | `register_file.write_data` |

**Vérifier les noms réels des ports** dans le VHDL de `writeback_mux`, qui peut avoir été nommé différemment.

### 11.8 Horloge et reset

Tous les blocs synchrones doivent recevoir une **horloge cohérente** :

- `program_counter.Clk`
- `program_memory.Clk`
- `instruction_register.Clk`
- `control_unit.Clk`
- `register_file.Clk`
- `flags_register.Clk`
- `data_ram.Clk`

Le reset doit aller aux blocs qui disposent d'un port `rst` : PC, IR, Control Unit, Register File, Flags Register. La ROM et la Data RAM actuelles n'ont pas de reset.

**Important :** ne pas relier un reset asynchrone actif bas à un reset synchrone actif haut sans adaptation de polarité et de synchronisation.

### 11.9 Valider et générer le wrapper

1. **Validate Design**.
2. **Generate Output Products**.
3. **Create HDL Wrapper**.
4. Définir le wrapper comme **Top** pour la synthèse, ou l'instancier dans un top/testbench.
5. Vérifier les avertissements de ports non connectés et de largeur de bus.

**Attention aux IP empaquetées :** modifier le VHDL source original ne met pas toujours à jour une IP déjà empaquetée. Vérifier **IP Status**, mettre à jour le dépôt IP et régénérer les Output Products si nécessaire.

---

## 12. Écriture de programmes assembleur

### 12.1 Syntaxe

```asm
; Commentaire
LABEL:
    INSTRUCTION OPERANDE1, OPERANDE2
```

Exemples :

```asm
LDI R0, 10
LDI R1, 0x14
ADD R0, R1
STORE R0, 0x10
HALT
```

Les registres vont de R0 à R7 ; les immédiats et adresses de 0 à 255.

### 12.2 Programme validé : 10 + 20

```asm
; program.asm
LDI R0, 10
LDI R1, 20
ADD R0, R1
STORE R0, 0x10
HALT
```

Traduction :

| Adresse ROM | Assembleur | Code machine |
|---:|---|---|
| `0x00` | `LDI R0, 10` | `900A` |
| `0x01` | `LDI R1, 20` | `9214` |
| `0x02` | `ADD R0, R1` | `1040` |
| `0x03` | `STORE R0, 0x10` | `B010` |
| `0x04` | `HALT` | `F000` |

Résultat vérifié dans Vivado :

```text
RAM[16] = 0x1E = 30
halted = 1
```

### 12.3 Programme de test LOAD

```asm
LDI R0, 15
LDI R1, 25
ADD R0, R1
STORE R0, 0x20
LOAD R3, 0x20
HALT
```

Résultats attendus : `R0 = 0x28`, `R3 = 0x28`, `RAM[32] = 0x28`. Ce test doit être **vérifié en simulation**, indépendamment du test ADD/STORE.

### 12.4 Programme de boucle : somme 1 à 5

```asm
LDI R0, 0      ; somme
LDI R1, 5      ; compteur
LDI R2, 1      ; constante 1
LDI R3, 0      ; zéro

LOOP:
    ADD R0, R1
    SUB R1, R2
    CMP R1, R3
    JZ END
    JMP LOOP

END:
    STORE R0, 0x20
    HALT
```

Résultat attendu : `RAM[32] = 0x0F` (15). Ce test permet de valider les sauts, les flags et la boucle ; il n'est pas encore déclaré validé tant que son chronogramme n'a pas été contrôlé.

---

## 13. Assembleur Python et génération de program.mem

### 13.1 Principe

```text
program.asm
    |
    v
assembler.py   (analyse + labels + encodage ISA)
    |
    v
program.mem    (1 instruction hexadécimale / ligne)
    |
    v
program_memory.vhd
    |
    v
CPU : FETCH → DECODE → EXECUTE
```

L'assembleur est un programme **exécuté sur le PC hôte**, pas dans le FPGA. Il convertit des mots-clés en mots binaires de 16 bits.

### 13.2 Organisation conseillée

```text
CPU_FPGA/
├── README.md
├── CPU_FPGA.xpr
├── assembler/
│   ├── assembler.py
│   └── program.asm
└── CPU_FPGA.srcs/
    └── sources_1/
        └── new/
            ├── alu.vhd
            ├── control_unit.vhd
            ├── data_ram.vhd
            ├── flags_register.vhd
            ├── instruction_decoder.vhd
            ├── instruction_register.vhd
            ├── program_counter.vhd
            ├── program_memory.vhd
            ├── register_file.vhd
            ├── writeback_mux.vhd
            └── program.mem
```

Les chemins peuvent différer selon la façon dont Vivado gère les IP empaquetées.

### 13.3 Commande de compilation

Depuis la racine du projet :

```bash
python3 assembler/assembler.py \
  assembler/program.asm \
  CPU_FPGA.srcs/sources_1/new/program.mem
```

Le script doit produire un mot hexadécimal de **quatre chiffres** par instruction :

```text
900A
9214
1040
B010
F000
```

### 13.4 Algorithme de l'assembleur

Un assembleur simple fonctionne en deux passes :

**Passe 1 : calculer les adresses des labels**

```text
LOOP:  → adresse de l'instruction suivante
END:   → adresse de fin
```

Chaque instruction occupe un mot ROM, donc chaque instruction incrémente l'adresse de 1. Une ligne de commentaire ou un label seul n'occupe pas de mot ROM.

**Passe 2 : encoder les instructions**

1. Reconnaître le mot-clé (`ADD`, `LDI`, `JZ`, etc.).
2. Vérifier le nombre et le type des opérandes.
3. Transformer `R3` en valeur 3.
4. Transformer `0x20` en valeur 32.
5. Remplacer les labels par leurs adresses.
6. Construire le mot de 16 bits selon le format R/I/J.
7. Écrire le mot en hexadécimal sur 4 chiffres.

### 13.5 Exemple d'encodeur minimal (illustration)

```python
OPCODES = {
    "NOP": 0x0, "ADD": 0x1, "SUB": 0x2, "AND": 0x3,
    "OR": 0x4, "XOR": 0x5, "NOT": 0x6, "SHL": 0x7,
    "SHR": 0x8, "LDI": 0x9, "LOAD": 0xA, "STORE": 0xB,
    "JMP": 0xC, "JZ": 0xD, "CMP": 0xE, "HALT": 0xF,
}


def encode_register(op, rd, rs=0):
    assert 0 <= rd <= 7 and 0 <= rs <= 7
    return (OPCODES[op] << 12) | (rd << 9) | (rs << 6)


def encode_immediate(op, rd, value):
    assert 0 <= rd <= 7 and 0 <= value <= 255
    return (OPCODES[op] << 12) | (rd << 9) | value


def encode_jump(op, address):
    assert 0 <= address <= 255
    return (OPCODES[op] << 12) | address


assert f"{encode_register('ADD', 0, 1):04X}" == "1040"
assert f"{encode_immediate('LDI', 1, 20):04X}" == "9214"
assert f"{encode_jump('JZ', 8):04X}" == "D008"
```

Cet extrait illustre l'encodage ; **le fichier `assembler.py` complet** doit aussi parser le texte, traiter les labels et signaler les erreurs. Il n'est pas remplacé par cet exemple.

### 13.6 Automatiser avec Vivado Tcl

Depuis la **Tcl Console** de Vivado :

```tcl
set project_dir [get_property DIRECTORY [current_project]]
set assembler "$project_dir/assembler/assembler.py"
set source "$project_dir/assembler/program.asm"
set output "$project_dir/CPU_FPGA.srcs/sources_1/new/program.mem"
exec python3 $assembler $source $output
```

Cela compile l'assembleur **à la demande**. Pour une compilation réellement automatique avant chaque simulation, il faut configurer un **hook pre-simulation** ou un script de lancement qui appelle d'abord Python, puis XSim.

---

## 14. ROM initialisée par fichier

### 14.1 Fichier `program.mem`

Le fichier contient **une instruction de 16 bits par ligne**, en hexadécimal, sans préfixe `0x` :

```text
900A
9214
1040
B010
F000
```

La ligne 1 initialise ROM[0], la ligne 2 ROM[1], etc.

### 14.2 Chargement VHDL

L'approche actuelle utilise une fonction d'initialisation et `hread` :

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;
```

Le cœur de la lecture est :

```vhdl
readline(rom_file, line_content);
hread(line_content, instruction);
rom_data(index) := instruction;
```

La fonction est appelée lors de l'initialisation :

```vhdl
signal ROM : rom_type := init_rom(MEM_FILE);
```

Le fichier doit être disponible au chemin résolu par `MEM_FILE`. Le chargement de la ROM est réalisé **à l'élaboration de la simulation**, pas à chaque cycle.

### 14.3 Emplacement du fichier

Emplacement utilisé pour ce projet :

```text
CPU_FPGA.srcs/sources_1/new/program.mem
```

Le nom seul `"program.mem"` dépend du répertoire de travail de Vivado. Un chemin absolu peut aider au diagnostic, mais rend le projet moins portable. Préférer ensuite une configuration de chemin reproductible.

### 14.4 Modifier un programme

1. Modifier `assembler/program.asm`.
2. Exécuter `assembler.py` pour régénérer `program.mem`.
3. **Redémarrer** la simulation afin de réinitialiser la ROM avec le nouveau fichier.
4. Vérifier que la nouvelle séquence est visible dans `ROM` et `Instruction_out`.

Sur un FPGA déjà configuré, changer `program.mem` **ne modifie pas automatiquement** le contenu de la ROM matérielle. Il faut en général régénérer le bitstream ou développer un mécanisme de chargement dynamique.

### 14.5 Synthèse et inférence ROM

Le chargement par TextIO est pratique en simulation, mais son support exact en synthèse dépend du style de code et de Vivado. Il faut **vérifier les rapports de synthèse et le contenu initialisé**. Si nécessaire, adapter la ROM à une méthode d'initialisation prise en charge par Vivado (par exemple `$readmemh` en Verilog, un fichier `.coe` pour Block Memory Generator, ou une initialisation VHDL compatible avec le flot retenu).

---

## 15. Simulation et validation

### 15.1 Testbench

Le testbench doit :

1. Générer une horloge (`Clk`).
2. Activer puis désactiver le reset (`rst`).
3. Instancier le wrapper du Block Design.
4. Attendre suffisamment de cycles pour l'exécution du programme.
5. Vérifier les sorties et les mémoires.
6. Signaler les erreurs par `assert` si possible.

Exemple de génération d'horloge à 100 MHz :

```vhdl
constant CLK_PERIOD : time := 10 ns;
signal Clk : std_logic := '0';

Clk <= not Clk after CLK_PERIOD / 2;
```

Exemple de reset :

```vhdl
rst <= '1';
wait for 30 ns;
rst <= '0';
```

### 15.2 Signaux à ajouter dans Waveform

Dans la fenêtre **Scopes**, développer la hiérarchie du testbench et du wrapper jusqu'aux instances :

| Instance | Signal | Ce qu'il indique |
|---|---|---|
| `program_counter_0` | `pc_out[7:0]` | Adresse programme |
| `program_memory_0` | `data_out[15:0]` | Instruction lue |
| `instruction_register_0` | `Instruction_out[15:0]` | Instruction en cours |
| `instruction_decoder_0` | `opcode`, `rd`, `rs`, `immediate` | Champs décodés |
| `control_unit_0` | `reg_write_enable`, `reg_write_sel`, `pc_enable`, `pc_load`, `halted` | Commandes |
| `alu_0` | `A`, `B`, `ALU_OP`, `RESULT` | Calcul combinatoire |
| `register_file_0` | `write_addr`, `write_data`, `write_enable` | Écriture registre |
| `flags_register_0` | `z_out`, `c_out`, `n_out`, `v_out` | Flags enregistrés |
| `data_ram_0` | `addr`, `write_data`, `read_data`, `write_enable`, `read_enable` | Accès RAM |

Faire clic droit sur les bus → **Radix → Hexadecimal**.

### 15.3 Observer directement la RAM

Dans le Scope de `data_ram_0`, chercher le tableau interne `RAM[0:255][7:0]` puis développer `RAM[16]`.

Pour le programme `10 + 20` :

```text
RAM[16] : 00 → 1E
```

Cela prouve qu'un octet `0x1E` a été écrit à l'adresse `0x10`.

**Attention :** un accès direct au tableau interne RAM est généralement possible en simulation RTL, mais pas nécessairement visible en tant que signal dans une ILA après synthèse.

### 15.4 Lire les chronogrammes correctement

- `data_out` de la ROM est **synchrone** : il suit l'adresse après un front montant.
- `Instruction_out` change quand `ir_enable` est actif au front montant.
- `alu.RESULT` est **combinatoire** : il peut varier hors de l'état EXECUTE.
- `register_file.write_data` est la **donnée candidate** ; elle n'est réellement mémorisée qu'au front où `write_enable=1`.
- `data_ram.write_data` est la donnée présentée à la RAM ; la preuve de l'écriture est `write_enable=1` au front montant et la modification de la case mémoire.
- `halted=1` prouve que la FSM est entrée dans l'état d'arrêt, **pas** à lui seul que tous les calculs sont corrects.

### 15.5 Exemple d'assertions

Si les ports de debug existent dans le testbench :

```vhdl
assert halted = '1'
    report "CPU did not halt"
    severity error;
```

Pour la RAM, on peut soit exposer un port de lecture de debug, soit observer la valeur via une instruction LOAD, soit vérifier le signal interne dans le testbench. Les assertions doivent correspondre aux signaux réellement accessibles.

---

## 16. Debug sur FPGA avec ILA

### 16.1 À quoi sert une ILA ?

L'**Integrated Logic Analyzer** (ILA) est un analyseur logique implémenté **dans le FPGA**. Il capture des signaux internes pendant l'exécution réelle du circuit.

**Simulation XSim** : comportement simulé du VHDL.

**ILA** : comportement observé après synthèse, implémentation et programmation de la carte.

### 16.2 Ajouter une ILA au Block Design

1. Ouvrir le Block Design.
2. **Add IP** → rechercher **ILA**.
3. Configurer le nombre de probes et leurs largeurs.
4. Connecter `clk` à l'horloge du CPU.
5. Connecter les probes aux signaux à surveiller.
6. **Validate Design**.
7. Générer les Output Products et le wrapper.
8. Lancer synthèse et implémentation, puis générer le bitstream.
9. Programmer le FPGA via **Hardware Manager**.
10. Déclencher une acquisition dans **hw_ila**.

### 16.3 Signaux ILA recommandés

| Probe | Largeur | Signal conseillé |
|---|---:|---|
| 0 | 8 | PC |
| 1 | 16 | Instruction Register |
| 2 | 4 | Opcode |
| 3 | 8 | ALU.RESULT |
| 4 | 8 | Register File write_data |
| 5 | 3 | Register File write_addr |
| 6 | 1 | Register File write_enable |
| 7 | 8 | RAM.addr |
| 8 | 8 | RAM.write_data |
| 9 | 1 | RAM.write_enable |
| 10 | 1 | RAM.read_enable |
| 11 | 1 | Flag Z |
| 12 | 1 | halted |

La configuration réelle peut utiliser moins de probes pour économiser les ressources FPGA. Les largeurs doivent correspondre exactement aux bus.

### 16.4 Comment déclencher une capture utile ?

Un programme de quelques instructions peut se terminer **très rapidement**. Si l'ILA est armée après la fin, les transitions sont déjà passées.

Stratégies :

- connecter un reset contrôlable depuis la carte ;
- **armer l'ILA avant de relâcher le reset** ;
- déclencher sur `ram_write_enable = 1` ;
- déclencher sur `halted = 1` avec une profondeur de pré-déclenchement suffisante ;
- exécuter un programme en boucle pendant le debug ;
- ajouter éventuellement un mécanisme de `step`/`clock enable` pour avancer instruction par instruction.

### 16.5 Lire une ILA

Dans Hardware Manager, sélectionner l'ILA et examiner les probes dans la fenêtre **Waveform**. Vérifier notamment :

```text
IR = 0x1040       (ADD R0, R1)
ALU.RESULT = 0x1E
...
IR = 0xB010       (STORE R0, 0x10)
RAM.addr = 0x10
RAM.write_data = 0x1E
RAM.write_enable = 1
```

Le timing de chaque signal doit être interprété par rapport aux états de la FSM et aux fronts d'horloge.

### 16.6 Limites de l'ILA

- La profondeur de capture est limitée par les ressources de la carte.
- Tous les tableaux mémoire internes ne sont pas directement observables après synthèse.
- La fréquence de l'horloge ILA doit être correcte et stable.
- Une ILA n'exécute pas le programme : elle **observe** les signaux du CPU.
- L'ILA n'est pas un substitut aux testbenches et aux assertions.

---

## 17. Problèmes fréquents

### 17.1 `hread is not declared`

Importer :

```vhdl
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;
```

Vérifier le mode VHDL-2008 du fichier si nécessaire.

### 17.2 `program.mem` introuvable

- Vérifier le chemin `MEM_FILE`.
- Vérifier le répertoire de travail de la simulation.
- Vérifier que le fichier est présent et lisible.
- Éviter de supposer que `program.mem` est automatiquement copié dans tous les répertoires de simulation.

### 17.3 Ancien programme toujours exécuté

La ROM est initialisée au démarrage de la simulation :

1. Sauvegarder `program.asm`.
2. Relancer `assembler.py`.
3. Fermer/redémarrer la simulation ou relancer l'élaboration.
4. Vérifier `ROM[0]` et `Instruction_out`.

### 17.4 Mauvais opcode dans la ROM

Ne pas réutiliser l'ancien encodage d'un autre CPU. **Dans l'ISA actuelle, `0x1005` est un opcode ADD, pas LDI.**

Exemples corrects :

```text
LDI R0,5   → 9005
LDI R1,3   → 9203
ADD R0,R1  → 1040
```

### 17.5 ALU correct, RAM incorrecte

Vérifier dans cet ordre :

1. `ALU.RESULT` au moment d'EXECUTE.
2. `writeback_mux` sélection `00`.
3. `register_file.write_enable`, `write_addr`, `write_data` au front WRITEBACK.
4. `register_file.read_data_a` avant STORE.
5. `data_ram.addr`, `write_data`, `write_enable` au front MEMORY.

### 17.6 LOAD retourne une ancienne valeur

La RAM est synchrone. Vérifier la séquence `MEMORY → MEMORY_WAIT → WRITEBACK` et le fait que `read_enable` est bien échantillonné au front montant.

### 17.7 JMP ou JZ saute au mauvais endroit

Vérifier :

- l'encodage de l'adresse sur 8 bits ;
- `instruction_decoder.jump_addr` ;
- `program_counter.pc_load_data` ;
- `pc_load` et le front montant ;
- les cycles de lecture ROM après le saut ;
- `flags_register.z_out` avant JZ.

### 17.8 IP modifiée mais Block Design inchangé

Si les blocs sont des IP empaquetées, mettre à jour les sources de l'IP, rafraîchir le dépôt IP, contrôler **IP Status** et régénérer les Output Products. Ne pas supposer que modifier un fichier VHDL externe met automatiquement à jour l'IP instanciée.

### 17.9 ILA ne capture rien

Vérifier :

- le bitstream et les probes correspondantes ;
- la fréquence d'horloge réelle ;
- l'état de l'ILA (`armed`, `triggered`) ;
- les conditions de trigger ;
- le fait que le CPU n'a pas déjà atteint HALT ;
- la nécessité d'un reset manuel ou d'une boucle de test.

---

## 18. Tests recommandés

| Test | Programme / action | Vérification | État |
|---|---|---|---|
| Chargement ROM | `program.mem` | ROM contient les mots attendus | **Observé en simulation** |
| ADD + STORE | 10 + 20 → RAM[0x10] | `RAM[16] = 0x1E` | **Validé en simulation** |
| HALT | `HALT` | `halted = 1` | **Observé en simulation** |
| LOAD | STORE puis LOAD | Valeur relue dans le registre | À vérifier |
| SUB | 50 - 20 | 30 | À vérifier |
| AND | `0x0C AND 0x0A` | `0x08` | À vérifier |
| OR | `0x0C OR 0x03` | `0x0F` | À vérifier |
| XOR | `0x0C XOR 0x0A` | `0x06` | À vérifier |
| NOT | `NOT 0x0F` | `0xF0` | À vérifier |
| SHL | 5 << 1 | 10 | À vérifier |
| SHR | 20 >> 1 | 10 | À vérifier |
| CMP + JZ | comparer deux valeurs égales | Saut pris | À vérifier |
| JZ non pris | comparer deux valeurs différentes | PC + 1 | À vérifier |
| Boucle | somme de 1 à 5 | RAM[32] = 15 | À vérifier |
| Overflow | 127 + 1 | `V=1`, résultat `0x80` | À vérifier |
| Carry | 250 + 20 | `C=1`, résultat `0x0E` | À vérifier |
| FPGA réel | exécution avec ILA | Trace cohérente | À vérifier |

### 18.1 Méthode de validation

Pour chaque instruction :

1. Écrire un petit `program.asm` autonome.
2. Générer `program.mem`.
3. Redémarrer la simulation.
4. Observer le PC, l'IR, les signaux de contrôle et les données.
5. Vérifier le résultat final et les flags concernés.
6. Ajouter une assertion au testbench.
7. Noter le résultat dans le tableau de tests.

Une instruction n'est considérée validée que lorsque ses **résultats et effets de bord** (PC, flags, mémoire) ont été vérifiés.

---

## 19. Limites et évolutions

### 19.1 Limites actuelles

- Seulement 8 registres généraux.
- Données et opérations arithmétiques limitées à 8 bits.
- 256 instructions maximum dans l'espace ROM actuel.
- 256 octets de RAM.
- Accès mémoire uniquement par adresse immédiate 8 bits.
- Pas de pile, sous-programmes ou interruptions.
- Pas de multiplication/division matérielles.
- Pas de GPIO/UART intégrés à l'ISA actuelle.
- Programme ROM non rechargeable dynamiquement sur FPGA sans mécanisme supplémentaire.
- 16 opcodes sur 4 bits : **l'espace des opcodes est entièrement occupé**.

### 19.2 Évolutions possibles

1. **Validation complète** de l'ISA avec tests automatiques.
2. **Débogueur instruction par instruction** avec `clock enable` ou FSM de debug.
3. **Sauts conditionnels supplémentaires** (`JNZ`, `JC`, `JN`) via sous-opcodes ou extension de l'ISA.
4. **Instruction MOV** entre registres.
5. **Adressage indirect** de la RAM.
6. **GPIO** et registres mémoire-mappés.
7. **UART** pour communication avec un PC.
8. **Mémoire programme rechargeable** (RAM programme + protocole UART).
9. **CALL / RET**, pile et interruptions.
10. **Analyse de timing et de ressources** : LUT, FF, BRAM, Fmax.

### 19.3 Charger un nouveau programme sans reconstruire le bitstream

Aujourd'hui :

```text
Modifier program.asm
    → assembler.py
    → program.mem
    → nouvelle simulation / nouveau bitstream
```

Évolution future :

```text
PC (programme assembleur)
    → assembler.py
    → image binaire
    → liaison UART
    → chargeur matériel FPGA
    → Program RAM
    → exécution CPU
```

Pour cela, il faudra remplacer ou compléter la ROM par une **mémoire programme inscriptible**, ajouter une interface de chargement et définir comment maintenir le CPU en reset/halt pendant le transfert.

---

## 20. Glossaire

| Terme | Définition |
|---|---|
| **CPU** | Processeur exécutant les instructions d'un programme |
| **ISA** | Contrat définissant instructions, formats, registres et effets |
| **Opcode** | Champ binaire identifiant une instruction |
| **Rd** | Registre destination |
| **Rs** | Registre source |
| **Immediate** | Valeur encodée directement dans l'instruction |
| **PC** | Program Counter, adresse programme |
| **IR** | Instruction Register, instruction courante |
| **ALU** | Arithmetic Logic Unit, bloc de calcul |
| **Register File** | Banc de registres internes du CPU |
| **ROM** | Mémoire programme initialisée et non modifiée pendant l'exécution actuelle |
| **RAM** | Mémoire de données accessible par LOAD/STORE |
| **FSM** | Finite State Machine, machine à états finis |
| **Datapath** | Chemin matériel des données : registres, ALU, mux, mémoires |
| **Control Unit** | Bloc qui pilote les activations et transitions d'états |
| **Writeback** | Écriture d'un résultat dans un registre |
| **Flag Z** | Indique un résultat nul |
| **Flag C** | Retenue ADD ou emprunt SUB dans ce projet |
| **Flag N** | Bit de poids fort du résultat |
| **Flag V** | Débordement arithmétique signé |
| **Block Design** | Schéma d'intégration de modules et IP dans Vivado |
| **ILA** | Integrated Logic Analyzer, capture de signaux internes sur FPGA |
| **XSim** | Simulateur Vivado |
| **Bitstream** | Fichier de configuration chargé dans le FPGA |

---

## Conclusion

Le projet **CPU_FPGA** démontre le chemin complet entre **logiciel et matériel** :

```text
Programme assembleur
       ↓
Assembleur Python
       ↓
Code machine 16 bits
       ↓
Program Memory
       ↓
Instruction Register
       ↓
Instruction Decoder + Control Unit
       ↓
Register File + ALU + Flags + Data RAM
       ↓
Résultat observé en simulation / ILA
```

Le test `LDI R0,10 → LDI R1,20 → ADD R0,R1 → STORE R0,0x10 → HALT` a permis d'observer **`RAM[16] = 0x1E`**, soit **30**, et le signal d'arrêt. Il constitue un premier jalon fonctionnel. La validation exhaustive de l'ISA, des timings et du fonctionnement sur FPGA physique est la suite du projet.

**Principe à retenir :** le CPU n'interprète pas directement les mots `ADD`, `LDI` ou `JMP`. Il exécute des **mots binaires de 16 bits** dont les champs sont décodés en commandes matérielles. L'assembleur Python est le pont entre le programme lisible par l'humain et le circuit VHDL.
