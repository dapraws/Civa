//
//  YearMonthField.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Month and year pickers for resume dates. The month is optional; no year means no date.
struct YearMonthField: View {
    let title: String
    @Binding var value: YearMonth?

    private static let years: [Int] = {
        let current = Calendar.current.component(.year, from: .now)
        return Array((1950...(current + 10)).reversed())
    }()

    var body: some View {
        LabeledContent(title) {
            HStack {
                Picker("\(title) month", selection: month) {
                    Text("No Month").tag(Int?.none)
                    ForEach(1...12, id: \.self) { month in
                        Text(Calendar.current.monthSymbols[month - 1]).tag(Int?.some(month))
                    }
                }
                .disabled(value == nil)

                Picker("\(title) year", selection: year) {
                    Text("No Date").tag(Int?.none)
                    ForEach(Self.years, id: \.self) { year in
                        Text(String(year)).tag(Int?.some(year))
                    }
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    private var year: Binding<Int?> {
        Binding(
            get: { value?.year },
            set: { newYear in value = newYear.map { YearMonth(year: $0, month: value?.month) } }
        )
    }

    private var month: Binding<Int?> {
        Binding(
            get: { value?.month },
            set: { newMonth in value = value.map { YearMonth(year: $0.year, month: newMonth) } }
        )
    }
}

#Preview {
    @Previewable @State var start: YearMonth? = YearMonth(year: 2024, month: 3)
    @Previewable @State var end: YearMonth?
    Form {
        YearMonthField(title: "Start", value: $start)
        YearMonthField(title: "End", value: $end)
    }
    .formStyle(.grouped)
}
