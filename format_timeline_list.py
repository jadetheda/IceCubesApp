import re

with open('Packages/Timeline/Sources/Timeline/View/TimelineListView.swift', 'r') as f:
    text = f.read()

# Just run a simple formatting with swiftformat if possible, or just fix indentation manually for the Group block
