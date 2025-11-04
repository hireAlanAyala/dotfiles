#!/usr/bin/gawk -f
# CSV to formatted table with truncation support
# Outputs table to stdout, cell metadata JSON to stderr

BEGIN {
    # Configuration
    FPAT = "([^,]*)|(\"[^\"]*\")"  # Handle quoted CSV fields
    OFS = " | "
    max_width = (MAX_WIDTH ? MAX_WIDTH : 20)  # Can be overridden with -v MAX_WIDTH=15

    row_count = 0
}

{
    row_count++

    # Process each field
    for (i = 1; i <= NF; i++) {
        # Remove surrounding quotes if present
        field = $i
        gsub(/^"|"$/, "", field)
        gsub(/^[ \t]+|[ \t]+$/, "", field)  # Trim whitespace

        # Store full text
        cells[row_count][i]["full"] = field

        # Truncate if needed
        if (length(field) > max_width) {
            truncated = substr(field, 1, max_width - 3) "..."
            cells[row_count][i]["truncated"] = truncated
            cells[row_count][i]["is_truncated"] = 1
        } else {
            cells[row_count][i]["truncated"] = field
            cells[row_count][i]["is_truncated"] = 0
        }

        # Track max width for each column (based on truncated text)
        cell_width = length(cells[row_count][i]["truncated"])
        if (cell_width > widths[i]) {
            widths[i] = cell_width
        }

        # Track number of columns
        if (i > num_cols) num_cols = i
    }
}

END {
    # Build JSON metadata string
    json = "{"
    first_cell = 1
    for (r = 1; r <= row_count; r++) {
        for (c = 1; c <= num_cols; c++) {
            if (!first_cell) json = json ","
            first_cell = 0

            # Escape quotes and backslashes in JSON
            full = cells[r][c]["full"]
            gsub(/\\/, "\\\\", full)
            gsub(/"/, "\\\"", full)

            truncated = cells[r][c]["truncated"]
            gsub(/\\/, "\\\\", truncated)
            gsub(/"/, "\\\"", truncated)

            json = json sprintf("\"%d:%d\":{\"full\":\"%s\",\"truncated\":\"%s\",\"is_truncated\":%d}", \
                r, c, full, truncated, cells[r][c]["is_truncated"])
        }
    }
    json = json "}"

    # Output JSON as a special marker line
    print "___CSV_METADATA___" json

    # Print header row
    printf "| "
    for (i = 1; i <= num_cols; i++) {
        printf "%-*s", widths[i], cells[1][i]["truncated"]
        printf (i < num_cols) ? " | " : " |\n"
    }

    # Print separator after header
    print_separator()

    # Print data rows
    for (r = 2; r <= row_count; r++) {
        printf "| "
        for (i = 1; i <= num_cols; i++) {
            printf "%-*s", widths[i], cells[r][i]["truncated"]
            printf (i < num_cols) ? " | " : " |\n"
        }
        print_separator()
    }
}

function print_separator() {
    printf "|"
    for (i = 1; i <= num_cols; i++) {
        for (j = 0; j < widths[i] + 2; j++) printf "-"
        printf (i < num_cols) ? "+" : "|\n"
    }
}
