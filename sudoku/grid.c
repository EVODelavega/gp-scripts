#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
    int i, x, y;
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

    grid->solved = 0;
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
            "| %d | %d | %d |",
            line->fields[i]->val,
            line->fields[i+1]->val,
            line->fields[i+2]->val
        );
    }
}

static
void print_grid(s_grid *grid)
{
    int i, j;
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

int main (void)
{
    s_grid *grid = init_grid();
    if (grid == NULL)
        return EXIT_FAILURE;
    //use grid
    print_grid(grid);
    dealloc_grid(grid);
    return EXIT_SUCCESS;
}
