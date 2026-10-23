#!/usr/bin/env python3
"""Two-pass assembler for the custom CPU-8 ISA."""
import argparse
import re
from pathlib import Path

OPCODES = {
    'NOP': 0x0, 'ADD': 0x1, 'SUB': 0x2, 'AND': 0x3,
    'OR': 0x4, 'XOR': 0x5, 'NOT': 0x6, 'SHL': 0x7,
    'SHR': 0x8, 'LDI': 0x9, 'LOAD': 0xA, 'STORE': 0xB,
    'JMP': 0xC, 'JZ': 0xD, 'CMP': 0xE, 'HALT': 0xF,
}
TWO_REG = {'ADD', 'SUB', 'AND', 'OR', 'XOR', 'CMP'}
ONE_REG = {'NOT', 'SHL', 'SHR'}
REG_IMM = {'LDI', 'LOAD', 'STORE'}
JUMPS = {'JMP', 'JZ'}
NO_ARGS = {'NOP', 'HALT'}
LABEL_RE = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*):')
REG_RE = re.compile(r'R([0-7])$', re.IGNORECASE)

class AssemblyError(ValueError):
    pass

def fail(line_number, message):
    raise AssemblyError(f'ligne {line_number}: {message}')

def parse_register(token, line_number):
    match = REG_RE.fullmatch(token.strip())
    if not match:
        fail(line_number, f'registre invalide {token!r} (attendu R0 à R7)')
    return int(match.group(1))

def parse_byte(token, labels, line_number):
    token = token.strip()
    if token in labels:
        value = labels[token]
    else:
        try:
            value = int(token, 0)
        except ValueError:
            fail(line_number, f'adresse/constante/label inconnu : {token!r}')
    if not 0 <= value <= 255:
        fail(line_number, f'valeur hors de 0..255 : {value}')
    return value

def parse_source(source):
    labels = {}
    instructions = []
    for lineno, raw in enumerate(source.splitlines(), start=1):
        line = raw.split(';', 1)[0].split('#', 1)[0].strip()
        if not line:
            continue
        while True:
            match = LABEL_RE.match(line)
            if not match:
                break
            name = match.group(1)
            if name in labels:
                fail(lineno, f'label défini deux fois : {name}')
            labels[name] = len(instructions)
            line = line[match.end():].strip()
            if not line:
                break
        if not line:
            continue
        instructions.append((lineno, line))
        if len(instructions) > 256:
            fail(lineno, 'programme trop long (maximum 256 instructions)')
    return labels, instructions

def assemble(source):
    labels, instructions = parse_source(source)
    words = []
    for lineno, line in instructions:
        parts = line.split(None, 1)
        mnemonic = parts[0].upper()
        if mnemonic not in OPCODES:
            fail(lineno, f'instruction inconnue : {mnemonic}')
        operands = [s.strip() for s in parts[1].split(',')] if len(parts) > 1 else []
        expected = 2 if mnemonic in TWO_REG | REG_IMM else 1 if mnemonic in ONE_REG | JUMPS else 0
        if len(operands) != expected or any(not p for p in operands):
            fail(lineno, f'{mnemonic} attend {expected} opérande(s), reçu {len(operands)}')
        word = OPCODES[mnemonic] << 12
        if mnemonic in TWO_REG:
            word |= (parse_register(operands[0], lineno) << 9)
            word |= (parse_register(operands[1], lineno) << 6)
        elif mnemonic in ONE_REG:
            word |= parse_register(operands[0], lineno) << 9
        elif mnemonic in REG_IMM:
            word |= parse_register(operands[0], lineno) << 9
            word |= parse_byte(operands[1], labels, lineno)
        elif mnemonic in JUMPS:
            word |= parse_byte(operands[0], labels, lineno)
        words.append(word)
    return words

def main():
    parser = argparse.ArgumentParser(description='Assembleur du CPU-8 VHDL')
    parser.add_argument('source', type=Path, help='Fichier assembleur .asm')
    parser.add_argument('output', type=Path, help='Fichier mémoire .mem')
    args = parser.parse_args()
    try:
        words = assemble(args.source.read_text(encoding='utf-8'))
    except (OSError, AssemblyError) as error:
        parser.exit(1, f'Erreur : {error}\n')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(''.join(f'{word:04X}\n' for word in words), encoding='ascii')
    print(f'OK : {len(words)} instructions → {args.output}')
    for address, word in enumerate(words):
        print(f'  {address:02X}: {word:04X}')

if __name__ == '__main__':
    main()
