# MADCounter - Madison Counter Unix Utility

## Implementation Status

**Status: FULLY IMPLEMENTED AND TESTED**

All features are working correctly and pass comprehensive testing.

## Author Information

- **Name**: [Your Name Here]
- **CS Login**: [Your CS Login]
- **WISC ID**: [Your WISC ID]
- **Email**: [Your Email]

## Implementation Summary

This project implements MADCounter, a command-line Unix utility that analyzes text files and generates statistics about their content. The program supports analysis of characters, words, lines, and can identify the longest words and lines in a file.

## Features Implemented

### Single-Run Mode
- **Character Analysis (-c)**: Tracks frequency and initial position of each ASCII character (0-127)
- **Word Analysis (-w)**: Tracks frequency and initial position of whitespace-separated words
- **Line Analysis (-l)**: Tracks frequency and initial position of newline-separated lines
- **Longest Word (-Lw)**: Identifies and displays the longest word(s) in alphabetical order
- **Longest Line (-Ll)**: Identifies and displays the longest line(s) in alphabetical order
- **Output File Support (-o)**: Writes results to file or stdout (default)

### Batch Mode
- **Batch File Processing (-B)**: Processes multiple analysis requests from a batch file
- **Error Handling**: Continues processing after encountering errors in batch commands
- **Independent Commands**: Each batch command is processed independently

### Error Handling
All required error cases are properly handled:
- Usage Error (insufficient arguments)
- Invalid Flag Types (unknown flags)
- Can't Open Batch File
- Batch File Empty
- No Input File Provided (missing -f flag)
- Can't Open Input File (file doesn't exist)
- No Output File Provided (missing filename after -o)
- Input File Empty

### Data Structures
- **Character Analysis**: Static arrays for O(1) frequency lookups
- **Word/Line Analysis**: Doubly-linked lists with alphabetical insertion sorting
- **Memory Management**: Proper allocation and deallocation of all dynamic memory

## Compilation

```bash
gcc -Wall -Werror -o MADCounter MADCounter.c
```

## Usage

### Single-Run Mode
```bash
./MADCounter -f <input file> [-o <output file>] [-c] [-w] [-l] [-Lw] [-Ll]
```

**Examples:**
```bash
# Analyze characters only
./MADCounter -f text.txt -c

# Analyze words and lines, write to file
./MADCounter -f text.txt -o output.txt -w -l

# All statistics
./MADCounter -f text.txt -o results.txt -c -w -l -Lw -Ll
```

### Batch Mode
```bash
./MADCounter -B <batch file>
```

**Example batch file contents:**
```
-f file1.txt -o out1.txt -c -w
-f file2.txt -o out2.txt -l -Lw -Ll
-f file3.txt -c
```

## Output Format

### Character Analysis
```
Total Number of Chars = <count>
Total Unique Chars = <count>

Ascii Value: <int>, Char: <char>, Count: <freq>, Initial Position: <pos>
...
```

### Word Analysis
```
Total Number of Words: <count>
Total Unique Words: <count>

Word: <string>, Freq: <freq>, Initial Position: <pos>
...
```

### Line Analysis
```
Total Number of Lines: <count>
Total Unique Lines: <count>

Line: <string>, Freq: <freq>, Initial Position: <pos>
...
```

### Longest Word/Line
```
Longest Word is <length> characters long:
	<word1>
	<word2>
	...

Longest Line is <length> characters long:
	<line1>
	<line2>
	...
```

## Implementation Details

### Key Algorithms

1. **Character Analysis**: Single pass with O(1) array indexing. Uses ASCII value as index.

2. **Word Analysis**: Alphabetical insertion into linked list. Each insertion:
   - Checks if word exists (update frequency)
   - If new, finds correct alphabetical position
   - Maintains sorted order for easy output

3. **Line Analysis**: Same as word analysis but uses `fgets()` instead of `fscanf()` and strips newlines.

4. **Longest Word/Line**: Finds maximum length, collects all items with that length, sorts alphabetically, and prints.

### Memory Management

- All dynamically allocated memory is properly freed
- Words and lines are freed after use in each analysis
- No memory leaks detected in testing
- Safe for batch mode with multiple file analyses

### Sorting

- **Characters**: Sorted by ASCII value (naturally in output loop)
- **Words/Lines**: Alphabetically sorted during linked list insertion using `strcmp()`

## Testing

The implementation has been tested with:
- Single character, word, and line analyses
- Combined analyses with proper newline separation
- Batch mode with multiple files and error conditions
- Edge cases (empty files, duplicate words, single words, multiple longest items)
- All error conditions specified in requirements



## Compilation Flags

The code compiles cleanly with:
```bash
gcc -Wall -Werror -o MADCounter MADCounter.c
```

No warnings or errors are produced.

## Notes

- All output is formatted exactly as specified in requirements
- Program exits with code 0 on success, 1 on error
- Batch mode continues processing even when individual commands fail
- Whitespace separation for words is as defined by C's `fscanf()` with "%s"
- Lines are read with `fgets()` and newlines are stripped before processing

---

**Implementation Date:** February 2026
**Language:** C
**Files:** MADCounter.c, README.md, resources.txt
