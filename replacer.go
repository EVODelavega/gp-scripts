package main

import (
    "bufio"
    "bytes"
    "fmt"
    "io"
    "os"
    "strings"
    //"unsafe"
)

/**
 * Replacer: copies file whilst replacing a given string
 * Example (not compiled): go run replacer.go /path/to/big/input.txt replaced.txt password '********'
 * Reads input.txt, copies it to the PWD, replasing all occurences of "password" with ********
 */

func main() {
    argv := os.Args[1:]
    if len(argv) != 4 {
        fmt.Println(os.Stderr, "Expected 4 arguments")
        return
    }
    file, err := os.Open(argv[0])
    if err != nil {
        panic(err)
    }
    defer file.Close()

    f, err := os.Create(argv[1])
    if err != nil {
        panic(err)
    }
    defer f.Close()
    w := bufio.NewWriter(f)

    reader := bufio.NewReader(file)
    buffer := bytes.NewBuffer(make([]byte, 0))
    var (
        part   []byte
        prefix bool
    )
    for {
        if part, prefix, err = reader.ReadLine(); err != nil {
            if err != io.EOF {
                fmt.Fprintln(os.Stderr, "error reading input file: ", err)
            }
            break
        }
        buffer.Write(part)
        buffer.WriteString("\n") //add the \n before writing to the new file:wq
        if !prefix {
            s := buffer.String()
            //unsafe, but perhaps a quicker alternative:
            //bb := buffer.Bytes()
            //s := *(*string)(unsafe.Pointer(&bb))
            _, err := w.WriteString(strings.Replace(s, argv[2], argv[3], -1))
            if err != nil {
                fmt.Fprintln(os.Stderr, "error writing file: ", err)
                break
            }
            w.Flush()
            buffer.Reset()
        }
    }

}
