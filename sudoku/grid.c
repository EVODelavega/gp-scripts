#include <stdio.h>
#include <stdlib.h>
#include <string.h>
//#include <stdbool.h>

typedef enum {
    LINE_HORIZONTAL,
    LINE_VERTICAL
} line_type;

typedef struct _s_field {
    int val;
    int h_pos;
    int v_pos;
    int valid[9];
    struct _s_block *block;
    struct _s_line *lines[2];
} s_field;

typedef struct _s_block {
    int v_pos;
    int h_pos;
    int valid[9];
    s_field *fields[9];
} s_block;

typedef struct _s_line {
    line_type type;
    int valid[9];
    s_field *fields[9];
} s_line;

/**
 
 struct foo {
  union {
    int sequential[9];
    int a2d[3][3];
  };
};

int main(void)
{
  int i, j;
  struct foo x;
  for (i=0;i<9;++i)
    x.sequential[i] = 1;
  //memset(x.sequential, 1, sizeof x.sequential);
  for (i=0;i<3;++i)
    for(j=0;j<3;++j)
      printf("x.a2d[%d][%d] = %d <=> x.sequential[%d] = %d\n", i, j, x.a2d[i][j], i*3+j, x.sequential[i*3+j]);
   return 0;
}

 */
typedef struct _s_grid {
    int valid_count[9];
    union {
        s_block *blocks_s[9];
        s_block *blocks_2d[3][3];
    };
    union {
        s_field *fields_s[81];
        s_field *fields_2d[9][9];
    };
    s_line *lines[2][9];
    int state_changed;
    int initialized;
    int solved;
} s_grid;

static
s_field *init_field(s_block *block, int field_offset)
{
    s_field *field = malloc(sizeof *field);
    if (field == NULL)
        return NULL;
    int i;
    for (i=0;i<9;++i)
        field->valid[i] = 1;

    field->block = block;
    field->val = 0;

    //set coordinates for field
    field->h_pos = field_offset%3;
    field->v_pos = ((field_offset - field->h_pos*3)%3) + block->v_pos*3;
    field->h_pos += block->h_pos*3;

    return field;
}

static
s_block *init_block(int offset)
{
    int i;
    s_block *block = malloc(sizeof *block);
    if (block == NULL)
        return NULL;
    block->v_pos = offset%3;
    block->h_pos = (offset - block->v_pos*3)%3;
    for (i=0;i<9;++i)
    {
            block->fields[i] = init_field(block, i);
            if (block->fields[i] == NULL)
            {
                while(i--)
                    free(block->fields[i]);
                free(block);
                return NULL;
            }
    }
    for (i=0;i<9;++i)
        block->valid[i] = 1;

    return block;
}

static
s_line *init_line(s_grid *grid, line_type type, int offset)
{
    int i, k = type == LINE_VERTICAL ? 1 : 0;
    s_line *line = malloc(sizeof *line);
    if (line == NULL)
        return NULL;
    //set line type
    line->type = type;
    if (type == LINE_VERTICAL)
    {
        //initialize valid array, add fields to line + link line to field
        for(i=0;i<9;++i)
        {
            line->fields[i] = grid->fields_2d[i][offset];
            line->fields[i]->lines[k] = line;
            line->valid[i] = 1;
        }
        return line;
    }
    //horizontal lines can be set using memcpy
    memcpy(line->fields, grid->fields_2d[offset], sizeof line->fields);
    for(i=0;i<9;++i)
    {
        line->valid[i] = 1;
        line->fields[i]->lines[k] = line;
    }
    return line;
}

static
s_grid *init_grid(void)
{
    int i;
    s_grid *grid = malloc(sizeof *grid);
    if (grid == NULL)
        return NULL;
    for (i=0;i<9;++i)
    {
        grid->blocks_s[i] = init_block(i);
        if (grid->blocks_s[i] == NULL)
        {
            while(i--)
                free(grid->blocks_s[i]);
            free(grid);
            return NULL;
        }
        //add field pointers to grid
        memcpy(
            grid->fields_2d[i],
            grid->blocks_s[i]->fields,
            sizeof grid->fields_2d[i]
        );
    }
    for (i=0;i<9;++i)
        grid->valid_count[i] = 9;

    grid->initialized = grid->state_changed = grid->solved = 0;
    //add lines:
    for (i=0;i<9;++i)
    {
        grid->lines[0][i] = init_line(
            grid,
            LINE_HORIZONTAL,
            i
        );
        grid->lines[1][i] = init_line(
            grid,
            LINE_VERTICAL,
            i
        );
    }
    return grid;
}

//we could do this in dealloc_grid, but this is easier to maintain
static
void dealloc_block(s_block *block)
{
    if (block == NULL)
        return;
    int i;
    for (i=0;i<9;++i)
        free(block->fields[i]);
    free(block);
}

static
void dealloc_grid(s_grid *grid)
{
    if (grid == NULL)
        return;
    //start with the lines (same as init, but reverse);
    int i;
    for (i=0;i<9;++i)
    {
        free(grid->lines[0][i]);
        free(grid->lines[1][i]);
        dealloc_block(grid->blocks_s[i]);
    }
    free(grid);
}

static
void print_line(s_line *line)
{
    int i;
    for (i=0;i<9;i+=3)
    {
        printf(
            "| %c | %c | %c |",
            line->fields[i]->val == 0 ? ' ' : line->fields[i]->val + '0',
            line->fields[i+1]->val == 0 ? ' ' : line->fields[i+1]->val + '0',
            line->fields[i+2]->val == 0 ? ' ' : line->fields[i+2]->val + '0'
        );
    }
}

static
void print_grid(s_grid *grid)
{
    int i;
    for (i=0;i<9;i+=3)
    {
        puts("|---|---|---||---|---|---||---|---|---|");
        print_line(grid->lines[0][i]);
        puts("");
        print_line(grid->lines[0][i+1]);
        puts("");
        print_line(grid->lines[0][i+2]);
        puts("");
    }
    puts("|---|---|---||---|---|---||---|---|---|");
}

static
void update_block_valids(s_block *block, int taken)
{
    int i;
    for (i=0;i<9;++i)
        block->fields[i]->valid[taken-1] = 0;
    block->valid[taken-1] = 0;
}

static
void update_line_valids(s_line *line, int taken)
{
    int i;
    for (i=0;i<9;++i)
        line->fields[i]->valid[taken-1] = 0;
    line->valid[taken-1] = 0;
}

//set field value, but check to make sure the value is allowed!
static
int set_field_value(s_field *field, int value)
{
    if (
        field->valid[value-1] == 0
        ||
        field->block->valid[value-1] == 0
        ||
        field->lines[0]->valid[value-1] == 0
        ||
        field->lines[1]->valid[value-1] == 0
    ) {
        return 1;
    }
    update_block_valids(field->block, value);
    field->val = value;
    update_line_valids(field->lines[0], value);
    update_line_valids(field->lines[1], value);
    return 0;
}

static
void init_from_file(const char *fname, s_grid *grid)
{
    FILE *fh = fopen(fname, "r");
    if (fh == NULL)
    {
        fprintf(stderr, "Failed to open file '%s'\n", fname);
        return;
    }
    int i = 0;
    while (i<81) {
        int ch = fgetc(fh);
        if (ch == EOF)
            break;
        if (ferror(fh))
        {
            fprintf(stderr, "Error reading from file");
            break;
        }
        ch -= '0';
        //make sure this is a valid integer value
        if (ch < 0 || ch > 9) {
            fprintf(
                stderr,
                "Invalid value '%c' (converted to %d)",
                ch + '0',
                ch
            );
            continue;//keep reading, take whitespace and \n characters into account?
        }
        if (ch != 0)
        {
            if (set_field_value(grid->fields_s[i], ch))
            {
                fprintf(stderr, "Invalid input -> value %d is duplicate", ch);
                fclose(fh);
                exit(1);
            }
            --grid->valid_count[ch-1];
        }
        else
            grid->fields_s[i]->val = 0;
        if (feof(fh))
            break;
        ++i;
    }
    fclose(fh);
    grid->initialized = 1;
}

static
int check_field(s_field *field)
{
    if (field->val != 0)
        return 0;//make sure we're not checking for no good reason
    int i, found = 0, last = 0;
    for (i=0;i<9;++i)
    {
        if (field->valid[i])
        {
            if (++found > 1)
                return 0;
            last = i+1;
        }
    }
    if (found == 1)
        set_field_value(field, last);
    else last = 0;
    return last;//will used to set solved flag...
}

static
void check_line(s_line *line)
{
	int i;
	size_t option_fields = 0;
	for (i=0;i<9;++i)
		if (line->fields[i]->val == 0) ++option_fields;
	for (int i=0;i<9;++i)
	{
		//if we still need this value, and the value can only be set in a specific field
		//in a specific block, remove all other possible values from said field
		/**
		 * >| 1 |<
		 * | 1, 3 | <-- only place where 1 can go in row, remove "3" option
		 * >| 5 |<
		 * =========
		 * | 3, 6 |
		 * | 6, 8 |
		 * >| 4 |<
		 * =========
		 */
		if (line->valid[i])
		{
		}
	}
}

static
void check_lines(s_grid *grid, line_type type)
{
	for (int i=0;i<9;++i)
	{
		//
	}
}


static
void update_solved(s_grid *grid)
{
    int k;
    for (k=0;k<9;++k)
        if (grid->valid_count[k])
            return;
    grid->solved = 1;//we can only ever reach this point if valid_count is 0 throughout
}

static
void solve_loop(s_grid *grid, int retries)
{
    int i, set;
    puts("Start solving puzzle");
    do {
        grid->state_changed = 0;
        for (i=0;i<81;++i)
        {
            set = check_field(grid->fields_s[i]);
            if (set != 0)
            {
                grid->state_changed = 1;
                --grid->valid_count[set-1];
            }
        }
        if (grid->state_changed)
            update_solved(grid);
    } while(grid->state_changed == 1 && grid->solved == 0);
    if (--retries > 0)
        return solve_loop(grid, retries);
}

int main (int argc, char **argv)
{
    s_grid *grid = init_grid();
    if (grid == NULL)
        return EXIT_FAILURE;
    //use grid
    if (argc > 1)
    {
        puts("Try to read from file");
        init_from_file(argv[1], grid);
    }
    print_grid(grid);
    if (grid->initialized)
    {
        solve_loop(grid, 1);
        puts("Puzzle after processing");
        print_grid(grid);
    }
    dealloc_grid(grid);
    return EXIT_SUCCESS;
}
