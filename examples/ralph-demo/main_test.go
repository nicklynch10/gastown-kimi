package main

import (
	"testing"
)

func TestCalculator_Add(t *testing.T) {
	calc := &Calculator{}
	result := calc.Add(2, 3)
	if result != 5 {
		t.Errorf("Add(2, 3) = %v, want 5", result)
	}
}

func TestCalculator_Subtract(t *testing.T) {
	calc := &Calculator{}
	result := calc.Subtract(5, 3)
	if result != 2 {
		t.Errorf("Subtract(5, 3) = %v, want 2", result)
	}
}

func TestCalculator_Multiply(t *testing.T) {
	calc := &Calculator{}
	result := calc.Multiply(4, 5)
	if result != 20 {
		t.Errorf("Multiply(4, 5) = %v, want 20", result)
	}
}

func TestCalculator_Divide(t *testing.T) {
	calc := &Calculator{}
	result, err := calc.Divide(10, 2)
	if err != nil {
		t.Errorf("Divide(10, 2) returned error: %v", err)
	}
	if result != 5 {
		t.Errorf("Divide(10, 2) = %v, want 5", result)
	}
}

func TestCalculator_DivideByZero(t *testing.T) {
	calc := &Calculator{}
	_, err := calc.Divide(10, 0)
	if err == nil {
		t.Error("Divide(10, 0) should return error")
	}
}
