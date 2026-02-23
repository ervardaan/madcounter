#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// =============================================================================
// CONSTANTS AND DEFINITIONS
// =============================================================================

// Maximum buffer sizes for reading from files
#define MAX_WORD_LENGTH 1000      // Max length of a single word
#define MAX_LINE_LENGTH 10000     // Max length of a single line
#define MAX_BATCH_LINE_LENGTH 10000  // Max length of a batch file line
#define ASCII_RANGE 128           // ASCII characters are 0-127 (128 total)
#define MAX_TOKENS 100            // Max number of command tokens in batch line
#define MAX_FLAGS 5               // Max number of analysis flags (-c, -w, -l, -Lw, -Ll)

// Flag order constants - used to track the order flags appear on the command line
#define FLAG_C  0   // Character analysis (-c)
#define FLAG_W  1   // Word analysis (-w)
#define FLAG_L  2   // Line analysis (-l)
#define FLAG_LW 3   // Longest word (-Lw)
#define FLAG_LL 4   // Longest line (-Ll)

// =============================================================================
// DATA STRUCTURES
// =============================================================================

// WORD struct - used for both word and line analysis
// This is a node in a linked list that stores information about a word or line
typedef struct word {
    char *contents;           // Pointer to the actual string (dynamically allocated)
    int numChars;             // Length of the string
    int frequency;            // How many times this word/line appears in the file
    int orderAppeared;        // Position where it first appeared (0-indexed)
    struct word *nextWord;    // Pointer to the next node in the linked list
    struct word *prevWord;    // Pointer to the previous node in the linked list
} WORD;

// =============================================================================
// FUNCTION PROTOTYPES
// =============================================================================

// Error handling functions - these print error messages to stdout
void printUsageError();
void printInvalidFlagError();
void printBatchOpenError();
void printBatchEmptyError();
void printNoInputFileError();
void printInputFileError();
void printNoOutputFileError();
void printInputFileEmptyError();

// Argument parsing function
int parseArguments(int argc, char *argv[],
                   char **inputFile,
                   char **outputFile,
                   int *requestCharAnalysis,
                   int *requestWordAnalysis,
                   int *requestLineAnalysis,
                   int *requestLongestWord,
                   int *requestLongestLine,
                   int flagOrder[],
                   int *flagCount);

// Main analysis function (returns 1 on success, 0 on error)
int analyzeFile(char *inputFile,
                 char *outputFile,
                 int requestCharAnalysis,
                 int requestWordAnalysis,
                 int requestLineAnalysis,
                 int requestLongestWord,
                 int requestLongestLine,
                 int flagOrder[],
                 int flagCount);

// Batch mode processing
void processBatchFile(char *batchFilename);

// CHARACTER ANALYSIS FUNCTIONS
void analyzeCharacters(FILE *fp,
                      int charFrequency[],
                      int charFirstPos[],
                      int *uniqueCharCount);
void printCharacterAnalysis(FILE *outputFile,
                           int charFrequency[],
                           int charFirstPos[],
                           int totalCharCount,
                           int uniqueCharCount);

// WORD ANALYSIS FUNCTIONS
WORD* insertWord(WORD *head, char *word, int position);
int countTotalWords(FILE *fp);
WORD* buildWordList(FILE *fp, int *totalWords, int *uniqueWords);
void printWordAnalysis(FILE *outputFile, WORD *wordHead, int totalWords, int uniqueWords);
void freeWordList(WORD *head);

// LINE ANALYSIS FUNCTIONS
WORD* insertLine(WORD *head, char *line, int position);
WORD* buildLineList(FILE *fp, int *totalLines, int *uniqueLines);
void printLineAnalysis(FILE *outputFile, WORD *lineHead, int totalLines, int uniqueLines);
void freeLineList(WORD *head);

// LONGEST WORD/LINE FUNCTIONS
void printLongestWord(FILE *outputFile, WORD *wordHead);
void printLongestLine(FILE *outputFile, WORD *lineHead);

// =============================================================================
// MAIN PROGRAM
// =============================================================================

int main(int argc, char *argv[]) {
    // Check if minimum arguments provided (program name + at least 2 more args)
    if (argc < 3) {
        printUsageError();
        return 1;
    }

    // Check if batch mode is requested
    if (strcmp(argv[1], "-B") == 0) {
        // Batch mode: argv[2] is the batch file name
        processBatchFile(argv[2]);
        return 0;
    } else {
        // Single-run mode: parse arguments and analyze one file
        char *inputFile = NULL;
        char *outputFile = NULL;
        int requestCharAnalysis = 0;
        int requestWordAnalysis = 0;
        int requestLineAnalysis = 0;
        int requestLongestWord = 0;
        int requestLongestLine = 0;
        int flagOrder[MAX_FLAGS];
        int flagCount = 0;

        // Parse and validate all arguments
        int parseResult = parseArguments(argc, argv,
                                        &inputFile,
                                        &outputFile,
                                        &requestCharAnalysis,
                                        &requestWordAnalysis,
                                        &requestLineAnalysis,
                                        &requestLongestWord,
                                        &requestLongestLine,
                                        flagOrder,
                                        &flagCount);

        if (parseResult == 0) {
            // Error in arguments - parseArguments already printed error message
            return 1;
        }

        // If we get here, arguments are valid - analyze the file
        int analyzeResult = analyzeFile(inputFile, outputFile,
                                       requestCharAnalysis,
                                       requestWordAnalysis,
                                       requestLineAnalysis,
                                       requestLongestWord,
                                       requestLongestLine,
                                       flagOrder,
                                       flagCount);

        // Return 0 if successful, 1 if error from analyzeFile
        return (analyzeResult == 1) ? 0 : 1;
    }
}

// =============================================================================
// ERROR PRINTING FUNCTIONS
// =============================================================================

void printUsageError() {
    printf("USAGE:\n");
    printf("\t./MADCounter -f <input file> -o <output file> -c -w -l -Lw -Ll\n");
    printf("\t\tOR\n");
    printf("\t./MADCounter -B <batch file>\n");
}

void printInvalidFlagError() {
    printf("ERROR: Invalid Flag Types\n");
}

void printBatchOpenError() {
    printf("ERROR: Can't open batch file\n");
}

void printBatchEmptyError() {
    printf("ERROR: Batch File Empty\n");
}

void printNoInputFileError() {
    printf("ERROR: No Input File Provided\n");
}

void printInputFileError() {
    printf("ERROR: Can't open input file\n");
}

void printNoOutputFileError() {
    printf("ERROR: No Output File Provided\n");
}

void printInputFileEmptyError() {
    printf("ERROR: Input File Empty\n");
}

// =============================================================================
// WORD ANALYSIS FUNCTIONS
// =============================================================================

// insertWord - Inserts a word into an alphabetically sorted doubly-linked list
// Handles both new words and duplicate words
// Parameters:
//   head: Pointer to the first node in the list (may be NULL for empty list)
//   word: The word to insert
//   position: The position (0-indexed) of this word in the file
// Returns: Pointer to the head of the list (will change if inserting at beginning)
WORD* insertWord(WORD *head, char *word, int position) {
    // First, check if this word already exists in the list
    WORD *current = head;
    while (current != NULL) {
        // Compare current word with the word we're trying to insert
        if (strcmp(current->contents, word) == 0) {
            // DUPLICATE WORD FOUND!
            // Increment frequency, don't change position
            current->frequency++;
            return head;  // Don't change list structure
        }

        // Not found yet, move to next node
        current = current->nextWord;
    }

    // Word not found - create a new node
    WORD *newNode = (WORD *)malloc(sizeof(WORD));
    if (newNode == NULL) {
        printf("ERROR: Memory allocation failed\n");
        exit(1);
    }

    // Allocate memory for the string content and copy it
    newNode->contents = (char *)malloc(strlen(word) + 1);
    if (newNode->contents == NULL) {
        printf("ERROR: Memory allocation failed\n");
        free(newNode);
        exit(1);
    }
    strcpy(newNode->contents, word);

    // Initialize the new node
    newNode->numChars = strlen(word);
    newNode->frequency = 1;
    newNode->orderAppeared = position;
    newNode->nextWord = NULL;
    newNode->prevWord = NULL;

    // If list is empty, this becomes the head
    if (head == NULL) {
        return newNode;
    }

    // Find the correct position to insert (maintain alphabetical order)
    current = head;
    while (current->nextWord != NULL && strcmp(current->contents, word) < 0) {
        // Keep moving forward while current word comes before new word alphabetically
        current = current->nextWord;
    }

    // Check if we need to insert before the current node
    if (strcmp(current->contents, word) > 0) {
        // Insert before current
        newNode->nextWord = current;
        newNode->prevWord = current->prevWord;

        if (current->prevWord != NULL) {
            current->prevWord->nextWord = newNode;
        }
        current->prevWord = newNode;

        // If current was the head, newNode becomes the new head
        if (current == head) {
            return newNode;
        }
        return head;
    } else {
        // Insert after current
        newNode->prevWord = current;
        newNode->nextWord = current->nextWord;

        if (current->nextWord != NULL) {
            current->nextWord->prevWord = newNode;
        }
        current->nextWord = newNode;

        return head;
    }
}

// countTotalWords - Counts the total number of words in the file
int countTotalWords(FILE *fp) {
    int count = 0;
    char buffer[MAX_WORD_LENGTH];

    // Use fscanf to read whitespace-separated words
    while (fscanf(fp, "%s", buffer) == 1) {
        count++;
    }

    return count;
}

// buildWordList - Creates a linked list of all unique words with their frequencies
WORD* buildWordList(FILE *fp, int *totalWords, int *uniqueWords) {
    WORD *head = NULL;
    char buffer[MAX_WORD_LENGTH];
    int wordIndex = 0;  // Track which word we're on (0-indexed)

    *totalWords = 0;
    *uniqueWords = 0;

    // Read each word from the file
    while (fscanf(fp, "%s", buffer) == 1) {
        (*totalWords)++;
        head = insertWord(head, buffer, wordIndex);
        wordIndex++;  // Move to next word position
    }

    // Count unique words by traversing the list
    WORD *current = head;
    while (current != NULL) {
        (*uniqueWords)++;
        current = current->nextWord;
    }

    return head;
}

// printWordAnalysis - Prints word statistics
void printWordAnalysis(FILE *outputFile, WORD *wordHead, int totalWords, int uniqueWords) {
    fprintf(outputFile, "Total Number of Words: %d\n", totalWords);
    fprintf(outputFile, "Total Unique Words: %d\n\n", uniqueWords);

    // List is already sorted alphabetically, so just traverse and print
    WORD *current = wordHead;
    while (current != NULL) {
        fprintf(outputFile, "Word: %s, Freq: %d, Initial Position: %d\n",
               current->contents, current->frequency, current->orderAppeared);
        current = current->nextWord;
    }
}

// freeWordList - Deallocates all nodes in the word list
void freeWordList(WORD *head) {
    WORD *current = head;
    while (current != NULL) {
        WORD *temp = current;
        current = current->nextWord;
        free(temp->contents);  // Free the string
        free(temp);            // Free the node
    }
}

// =============================================================================
// parseArguments - Validates command-line arguments for single-run mode
// =============================================================================
// Parameters:
//   argc, argv: Command-line arguments from main()
//   inputFile: Pointer to store input filename (set by -f flag)
//   outputFile: Pointer to store output filename (set by -o flag, can be NULL)
//   requestCharAnalysis: Set to 1 if -c flag is present
//   requestWordAnalysis: Set to 1 if -w flag is present
//   requestLineAnalysis: Set to 1 if -l flag is present
//   requestLongestWord: Set to 1 if -Lw flag is present
//   requestLongestLine: Set to 1 if -Ll flag is present
//
// Return: 1 if all arguments are valid, 0 if error (error message already printed)
// =============================================================================
int parseArguments(int argc, char *argv[],
                   char **inputFile,
                   char **outputFile,
                   int *requestCharAnalysis,
                   int *requestWordAnalysis,
                   int *requestLineAnalysis,
                   int *requestLongestWord,
                   int *requestLongestLine,
                   int flagOrder[],
                   int *flagCount) {

    // Initialize all output parameters to their default values
    *inputFile = NULL;
    *outputFile = NULL;
    *requestCharAnalysis = 0;
    *requestWordAnalysis = 0;
    *requestLineAnalysis = 0;
    *requestLongestWord = 0;
    *requestLongestLine = 0;
    *flagCount = 0;

    // Loop through all arguments starting at index 1 (skip program name at argv[0])
    for (int i = 1; i < argc; i++) {
        char *arg = argv[i];

        // Check if this argument starts with "-" (it's a flag)
        if (arg[0] == '-') {

            // Handle -f flag (input file)
            if (strcmp(arg, "-f") == 0) {
                // -f needs a parameter: the input filename
                // Check if there's a next argument
                if (i + 1 >= argc) {
                    // No next argument available, so no filename provided
                    printNoInputFileError();
                    return 0;
                }

                // Get the next argument - should be the filename
                char *nextArg = argv[i + 1];

                // Validate that the next argument is NOT a flag
                // (flags start with "-", filenames shouldn't)
                if (nextArg[0] == '-') {
                    // Next argument is a flag, not a filename
                    printNoInputFileError();
                    return 0;
                }

                // Valid: store the filename and skip the next argument
                *inputFile = nextArg;
                i++;  // Skip the filename we just processed
            }

            // Handle -o flag (output file)
            else if (strcmp(arg, "-o") == 0) {
                // -o needs a parameter: the output filename
                // Check if there's a next argument
                if (i + 1 >= argc) {
                    // No next argument available
                    printNoOutputFileError();
                    return 0;
                }

                // Get the next argument - should be the filename
                char *nextArg = argv[i + 1];

                // Validate that the next argument is NOT a flag
                if (nextArg[0] == '-') {
                    // Next argument is a flag, not a filename
                    printNoOutputFileError();
                    return 0;
                }

                // Valid: store the filename and skip the next argument
                *outputFile = nextArg;
                i++;  // Skip the filename we just processed
            }

            // Handle -c flag (character analysis)
            else if (strcmp(arg, "-c") == 0) {
                // No parameter needed - just set the flag
                if (!*requestCharAnalysis) {
                    flagOrder[(*flagCount)++] = FLAG_C;
                }
                *requestCharAnalysis = 1;
            }

            // Handle -w flag (word analysis)
            else if (strcmp(arg, "-w") == 0) {
                // No parameter needed - just set the flag
                if (!*requestWordAnalysis) {
                    flagOrder[(*flagCount)++] = FLAG_W;
                }
                *requestWordAnalysis = 1;
            }

            // Handle -l flag (line analysis)
            else if (strcmp(arg, "-l") == 0) {
                // No parameter needed - just set the flag
                if (!*requestLineAnalysis) {
                    flagOrder[(*flagCount)++] = FLAG_L;
                }
                *requestLineAnalysis = 1;
            }

            // Handle -Lw flag (longest word)
            else if (strcmp(arg, "-Lw") == 0) {
                // No parameter needed - just set the flag
                if (!*requestLongestWord) {
                    flagOrder[(*flagCount)++] = FLAG_LW;
                }
                *requestLongestWord = 1;
            }

            // Handle -Ll flag (longest line)
            else if (strcmp(arg, "-Ll") == 0) {
                // No parameter needed - just set the flag
                if (!*requestLongestLine) {
                    flagOrder[(*flagCount)++] = FLAG_LL;
                }
                *requestLongestLine = 1;
            }

            // Unknown flag - not one of our valid flags
            else {
                // This is a flag (starts with -) but it's not recognized
                printInvalidFlagError();
                return 0;
            }
        }
        // If argument doesn't start with "-", it's invalid
        // (all arguments except filenames for -f and -o should be flags)
        else {
            // This argument doesn't start with "-" and isn't a filename following -f or -o
            // (if it were, it would have been processed above)
            printInvalidFlagError();
            return 0;
        }
    }

    // After processing all arguments, validate that required flags are present
    // The -f flag (input file) is REQUIRED
    if (*inputFile == NULL) {
        // No input file was specified with -f flag
        printNoInputFileError();
        return 0;
    }

    // All arguments are valid!
    return 1;
}

// =============================================================================
// LINE ANALYSIS FUNCTIONS
// =============================================================================

// insertLine - Inserts a line into an alphabetically sorted doubly-linked list
// Same logic as insertWord, but for lines
WORD* insertLine(WORD *head, char *line, int position) {
    // Check if this line already exists
    WORD *current = head;
    while (current != NULL) {
        if (strcmp(current->contents, line) == 0) {
            // DUPLICATE LINE FOUND!
            current->frequency++;
            return head;
        }
        current = current->nextWord;
    }

    // Create new node for new line
    WORD *newNode = (WORD *)malloc(sizeof(WORD));
    if (newNode == NULL) {
        printf("ERROR: Memory allocation failed\n");
        exit(1);
    }

    newNode->contents = (char *)malloc(strlen(line) + 1);
    if (newNode->contents == NULL) {
        printf("ERROR: Memory allocation failed\n");
        free(newNode);
        exit(1);
    }
    strcpy(newNode->contents, line);

    newNode->numChars = strlen(line);
    newNode->frequency = 1;
    newNode->orderAppeared = position;
    newNode->nextWord = NULL;
    newNode->prevWord = NULL;

    // If list is empty, this becomes the head
    if (head == NULL) {
        return newNode;
    }

    // Find correct insertion position (alphabetical order)
    current = head;
    while (current->nextWord != NULL && strcmp(current->contents, line) < 0) {
        current = current->nextWord;
    }

    // Insert before current?
    if (strcmp(current->contents, line) > 0) {
        newNode->nextWord = current;
        newNode->prevWord = current->prevWord;

        if (current->prevWord != NULL) {
            current->prevWord->nextWord = newNode;
        }
        current->prevWord = newNode;

        if (current == head) {
            return newNode;
        }
        return head;
    } else {
        // Insert after current
        newNode->prevWord = current;
        newNode->nextWord = current->nextWord;

        if (current->nextWord != NULL) {
            current->nextWord->prevWord = newNode;
        }
        current->nextWord = newNode;

        return head;
    }
}

// buildLineList - Creates a linked list of all unique lines with their frequencies
WORD* buildLineList(FILE *fp, int *totalLines, int *uniqueLines) {
    WORD *head = NULL;
    char buffer[MAX_LINE_LENGTH];
    int lineIndex = 0;  // Track which line we're on (0-indexed)

    *totalLines = 0;
    *uniqueLines = 0;

    // Read each line from the file
    while (fgets(buffer, MAX_LINE_LENGTH, fp) != NULL) {
        (*totalLines)++;

        // Remove trailing newline if present
        if (buffer[strlen(buffer) - 1] == '\n') {
            buffer[strlen(buffer) - 1] = '\0';
        }

        head = insertLine(head, buffer, lineIndex);
        lineIndex++;
    }

    // Count unique lines by traversing the list
    WORD *current = head;
    while (current != NULL) {
        (*uniqueLines)++;
        current = current->nextWord;
    }

    return head;
}

// printLineAnalysis - Prints line statistics
void printLineAnalysis(FILE *outputFile, WORD *lineHead, int totalLines, int uniqueLines) {
    fprintf(outputFile, "Total Number of Lines: %d\n", totalLines);
    fprintf(outputFile, "Total Unique Lines: %d\n\n", uniqueLines);

    // List is already sorted alphabetically
    WORD *current = lineHead;
    while (current != NULL) {
        fprintf(outputFile, "Line: %s, Freq: %d, Initial Position: %d\n",
               current->contents, current->frequency, current->orderAppeared);
        current = current->nextWord;
    }
}

// freeLineList - Deallocates all nodes in the line list
void freeLineList(WORD *head) {
    WORD *current = head;
    while (current != NULL) {
        WORD *temp = current;
        current = current->nextWord;
        free(temp->contents);
        free(temp);
    }
}

// =============================================================================
// LONGEST WORD/LINE FUNCTIONS
// =============================================================================

// printLongestWord - Finds and prints the longest word(s)
void printLongestWord(FILE *outputFile, WORD *wordHead) {
    if (wordHead == NULL) {
        return;
    }

    // Find the maximum length among all words
    int maxLength = 0;
    WORD *current = wordHead;
    while (current != NULL) {
        if (current->numChars > maxLength) {
            maxLength = current->numChars;
        }
        current = current->nextWord;
    }

    // Collect all words with maximum length
    WORD **longestWords = (WORD **)malloc(sizeof(WORD *) * 1000);
    int longestCount = 0;

    current = wordHead;
    while (current != NULL) {
        if (current->numChars == maxLength) {
            longestWords[longestCount++] = current;
        }
        current = current->nextWord;
    }

    // Sort the longest words alphabetically
    // (They might not be consecutive in the original list)
    for (int i = 0; i < longestCount - 1; i++) {
        for (int j = i + 1; j < longestCount; j++) {
            if (strcmp(longestWords[i]->contents, longestWords[j]->contents) > 0) {
                // Swap
                WORD *temp = longestWords[i];
                longestWords[i] = longestWords[j];
                longestWords[j] = temp;
            }
        }
    }

    // Print the longest word(s)
    fprintf(outputFile, "Longest Word is %d characters long:\n", maxLength);
    for (int i = 0; i < longestCount; i++) {
        fprintf(outputFile, "\t%s\n", longestWords[i]->contents);
    }

    free(longestWords);
}

// printLongestLine - Finds and prints the longest line(s)
void printLongestLine(FILE *outputFile, WORD *lineHead) {
    if (lineHead == NULL) {
        return;
    }

    // Find the maximum length among all lines
    int maxLength = 0;
    WORD *current = lineHead;
    while (current != NULL) {
        if (current->numChars > maxLength) {
            maxLength = current->numChars;
        }
        current = current->nextWord;
    }

    // Collect all lines with maximum length
    WORD **longestLines = (WORD **)malloc(sizeof(WORD *) * 1000);
    int longestCount = 0;

    current = lineHead;
    while (current != NULL) {
        if (current->numChars == maxLength) {
            longestLines[longestCount++] = current;
        }
        current = current->nextWord;
    }

    // Sort the longest lines alphabetically
    for (int i = 0; i < longestCount - 1; i++) {
        for (int j = i + 1; j < longestCount; j++) {
            if (strcmp(longestLines[i]->contents, longestLines[j]->contents) > 0) {
                // Swap
                WORD *temp = longestLines[i];
                longestLines[i] = longestLines[j];
                longestLines[j] = temp;
            }
        }
    }

    // Print the longest line(s)
    fprintf(outputFile, "Longest Line is %d characters long:\n", maxLength);
    for (int i = 0; i < longestCount; i++) {
        fprintf(outputFile, "\t%s\n", longestLines[i]->contents);
    }

    free(longestLines);
}

// analyzeCharacters - Counts frequency and position of each character
// Reads file character by character and tracks:
// - How many times each character appears
// - The first position each character appears at
void analyzeCharacters(FILE *fp,
                      int charFrequency[],
                      int charFirstPos[],
                      int *uniqueCharCount) {
    int c;
    int charPosition = 0;

    // Initialize arrays to 0
    for (int i = 0; i < ASCII_RANGE; i++) {
        charFrequency[i] = 0;
        charFirstPos[i] = 0;
    }

    *uniqueCharCount = 0;

    // Read file character by character
    while ((c = fgetc(fp)) != EOF) {
        // For each character, increment its frequency
        if (charFrequency[c] == 0) {
            // First time seeing this character
            *uniqueCharCount += 1;
            charFirstPos[c] = charPosition;
        }
        charFrequency[c]++;
        charPosition++;
    }
}

// printCharacterAnalysis - Prints all character statistics
void printCharacterAnalysis(FILE *outputFile,
                           int charFrequency[],
                           int charFirstPos[],
                           int totalCharCount,
                           int uniqueCharCount) {
    fprintf(outputFile, "Total Number of Chars = %d\n", totalCharCount);
    fprintf(outputFile, "Total Unique Chars = %d\n\n", uniqueCharCount);

    // Loop through all ASCII values (0-127) and print if character appeared
    for (int i = 0; i < ASCII_RANGE; i++) {
        if (charFrequency[i] > 0) {
            // Character appeared in file
            fprintf(outputFile, "Ascii Value: %d, Char: %c, Count: %d, Initial Position: %d\n",
                   i, i, charFrequency[i], charFirstPos[i]);
        }
    }
}

// =============================================================================
// analyzeFile - Main function for analyzing a single file
// Returns: 1 on success, 0 on error
// =============================================================================
int analyzeFile(char *inputFile,
                 char *outputFile,
                 int requestCharAnalysis,
                 int requestWordAnalysis,
                 int requestLineAnalysis,
                 int requestLongestWord,
                 int requestLongestLine,
                 int flagOrder[],
                 int flagCount) {

    // Try to open the input file for reading
    FILE *inputFP = fopen(inputFile, "r");
    if (inputFP == NULL) {
        // File cannot be opened (doesn't exist, permission denied, etc.)
        printInputFileError();
        return 0;  // Error
    }

    // Check if input file is empty
    fseek(inputFP, 0, SEEK_END);
    long fileSize = ftell(inputFP);
    fseek(inputFP, 0, SEEK_SET);

    if (fileSize == 0) {
        printInputFileEmptyError();
        fclose(inputFP);
        return 0;  // Error
    }

    // Determine output destination: file or stdout
    FILE *outputFP = stdout;
    if (outputFile != NULL) {
        outputFP = fopen(outputFile, "w");
        if (outputFP == NULL) {
            printf("ERROR: Can't open output file\n");
            fclose(inputFP);
            return 0;  // Error
        }
    }

    // =========================================================================
    // PHASE 1: Build all data structures (silently, regardless of print order)
    // =========================================================================

    // CHARACTER data (only if -c requested)
    int charFrequency[ASCII_RANGE];
    int charFirstPos[ASCII_RANGE];
    int uniqueCharCount = 0;
    if (requestCharAnalysis) {
        analyzeCharacters(inputFP, charFrequency, charFirstPos, &uniqueCharCount);
        fseek(inputFP, 0, SEEK_SET);
    }

    // WORD LIST (build if -w or -Lw requested)
    WORD *wordHead = NULL;
    int totalWords = 0;
    int uniqueWords = 0;
    if (requestWordAnalysis || requestLongestWord) {
        wordHead = buildWordList(inputFP, &totalWords, &uniqueWords);
        fseek(inputFP, 0, SEEK_SET);
    }

    // LINE LIST (build if -l or -Ll requested)
    WORD *lineHead = NULL;
    int totalLines = 0;
    int uniqueLines = 0;
    if (requestLineAnalysis || requestLongestLine) {
        lineHead = buildLineList(inputFP, &totalLines, &uniqueLines);
        fseek(inputFP, 0, SEEK_SET);
    }

    // =========================================================================
    // PHASE 2: Print sections in the ORDER the flags appeared on the command line
    // =========================================================================
    // We add ONE blank line BEFORE each section (except the very first one)
    // so sections are separated by exactly one blank line.

    int firstSection = 1;  // Tracks if we've printed anything yet

    for (int i = 0; i < flagCount; i++) {
        // Add separator before every section except the first
        if (!firstSection) {
            fprintf(outputFP, "\n");
        }

        switch (flagOrder[i]) {
            case FLAG_C:
                printCharacterAnalysis(outputFP, charFrequency, charFirstPos,
                                       (int)fileSize, uniqueCharCount);
                firstSection = 0;
                break;

            case FLAG_W:
                if (wordHead != NULL || totalWords == 0) {
                    printWordAnalysis(outputFP, wordHead, totalWords, uniqueWords);
                    firstSection = 0;
                }
                break;

            case FLAG_L:
                if (lineHead != NULL || totalLines == 0) {
                    printLineAnalysis(outputFP, lineHead, totalLines, uniqueLines);
                    firstSection = 0;
                }
                break;

            case FLAG_LW:
                if (wordHead != NULL) {
                    printLongestWord(outputFP, wordHead);
                    firstSection = 0;
                }
                break;

            case FLAG_LL:
                if (lineHead != NULL) {
                    printLongestLine(outputFP, lineHead);
                    firstSection = 0;
                }
                break;
        }
    }

    // Free allocated memory
    if (wordHead != NULL) {
        freeWordList(wordHead);
    }
    if (lineHead != NULL) {
        freeLineList(lineHead);
    }

    // Close files
    fclose(inputFP);
    if (outputFile != NULL) {
        fclose(outputFP);
    }

    return 1;  // Success
}

void processBatchFile(char *batchFilename) {
    // Try to open the batch file
    FILE *batchFP = fopen(batchFilename, "r");
    if (batchFP == NULL) {
        printBatchOpenError();
        return;
    }

    // Check if batch file is empty by trying to read the first line
    char batchLine[MAX_BATCH_LINE_LENGTH];
    if (fgets(batchLine, MAX_BATCH_LINE_LENGTH, batchFP) == NULL) {
        // File is empty
        printBatchEmptyError();
        fclose(batchFP);
        return;
    }

    // Process first line, then remaining lines
    do {
        // Remove trailing newline if present
        if (batchLine[strlen(batchLine) - 1] == '\n') {
            batchLine[strlen(batchLine) - 1] = '\0';
        }

        // Skip empty lines
        if (strlen(batchLine) == 0) {
            continue;
        }

        // Parse the batch line into argc/argv format
        // We'll create an argv array by splitting the line by spaces
        char *tokens[MAX_TOKENS + 1];  // Extra space for fake argv[0]
        int tokenCount = 0;
        char lineCopy[MAX_BATCH_LINE_LENGTH];
        strcpy(lineCopy, batchLine);

        // Add fake program name at argv[0]
        tokens[0] = "MADCounter";

        // Tokenize the line by spaces
        char *token = strtok(lineCopy, " ");
        while (token != NULL && tokenCount < MAX_TOKENS) {
            tokens[tokenCount + 1] = token;  // +1 to account for argv[0]
            tokenCount++;
            token = strtok(NULL, " ");
        }

        // Now we have argc and argv for this batch command
        // argc includes the fake program name, so it's tokenCount + 1
        int batchArgc = tokenCount + 1;

        // Now we have argc and argv for this batch command
        // Parse and analyze
        if (batchArgc >= 3) {
            char *inputFile = NULL;
            char *outputFile = NULL;
            int requestCharAnalysis = 0;
            int requestWordAnalysis = 0;
            int requestLineAnalysis = 0;
            int requestLongestWord = 0;
            int requestLongestLine = 0;
            int flagOrder[MAX_FLAGS];
            int flagCount = 0;

            // Parse the arguments for this batch command
            int parseResult = parseArguments(batchArgc, tokens,
                                            &inputFile,
                                            &outputFile,
                                            &requestCharAnalysis,
                                            &requestWordAnalysis,
                                            &requestLineAnalysis,
                                            &requestLongestWord,
                                            &requestLongestLine,
                                            flagOrder,
                                            &flagCount);

            if (parseResult == 1) {
                // Arguments are valid - analyze the file
                analyzeFile(inputFile, outputFile,
                           requestCharAnalysis,
                           requestWordAnalysis,
                           requestLineAnalysis,
                           requestLongestWord,
                           requestLongestLine,
                           flagOrder,
                           flagCount);
            }
            // If parseResult == 0, error message was already printed by parseArguments
        }
    } while (fgets(batchLine, MAX_BATCH_LINE_LENGTH, batchFP) != NULL);

    // Close the batch file
    fclose(batchFP);
}
