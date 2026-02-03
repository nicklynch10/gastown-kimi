package main

import (
	"fmt"
	"os"
	"strconv"
)

// Calculator provides basic math operations
type Calculator struct{}

// Add returns the sum of two numbers
func (c *Calculator) Add(a, b float64) float64 {
	return a + b
}

// Subtract returns the difference of two numbers
func (c *Calculator) Subtract(a, b float64) float64 {
	return a - b
}

// Multiply returns the product of two numbers
func (c *Calculator) Multiply(a, b float64) float64 {
	return a * b
}

// Divide returns the quotient of two numbers
func (c *Calculator) Divide(a, b float64) (float64, error) {
	if b == 0 {
		return 0, fmt.Errorf("cannot divide by zero")
	}
	return a / b, nil
}

func main() {
	if len(os.Args) < 4 {
		fmt.Println("Usage: ralph-demo <operation> <num1> <num2>")
		fmt.Println("Operations: add, subtract, multiply, divide")
		os.Exit(1)
	}

	operation := os.Args[1]
	a, err1 := strconv.ParseFloat(os.Args[2], 64)
	b, err2 := strconv.ParseFloat(os.Args[3], 64)

	if err1 != nil || err2 != nil {
		fmt.Println("Error: Invalid numbers")
		os.Exit(1)
	}

	calc := &Calculator{}
	var result float64
	var err error

	switch operation {
	case "add":
		result = calc.Add(a, b)
	case "subtract":
		result = calc.Subtract(a, b)
	case "multiply":
		result = calc.Multiply(a, b)
	case "divide":
		result, err = calc.Divide(a, b)
	default:
		fmt.Printf("Unknown operation: %s\n", operation)
		os.Exit(1)
	}

	if err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("%.2f\n", result)
}
