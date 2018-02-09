//
//  ViewController.swift
//  Currency converter
//
//  Created by Denis Samodurov on 09/02/2018.
//  Copyright © 2018 Denis Samodurov. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate{
    
    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var pickerFrom: UIPickerView!
    @IBOutlet weak var pickerTo: UIPickerView!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    static let defualtCodes = ["EUR", "RON", "MYR", "ISK", "CAD", "DKK", "GBP", "PHP", "CZK", "PLN", "RUB", "SGD",
                               "BRL", "JPY", "SEK", "USD", "HRK", "NZD", "HKD", "BGN", "TRY", "MXN", "HUF", "KRW",
                               "NOK", "INR", "ILS", "IDR", "CHF", "THB", "CNY", "ZAR", "AUD"]
    var currencies = defualtCodes
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.label.text = "Тут будет курс"
        
        self.pickerFrom.dataSource = self
        self.pickerTo.dataSource = self
        
        self.pickerFrom.delegate = self
        self.pickerTo.delegate = self
        
        self.activityIndicator.hidesWhenStopped = true
        self.requestCurrentCurrencyRate()
        self.requestCurrentCurrencyCodes()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1;
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView === pickerTo {
            return self.currenciesExceptBase().count
        }
        return currencies.count
    }
    
    // MARK: - UIPickerViewDelegate
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView === pickerTo {
            return self.currenciesExceptBase()[row]
        }
        return currencies[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
//        if pickerView === pickerTo {
            self.pickerTo.reloadAllComponents()
//        }
        self.requestCurrentCurrencyRate()
    }
    
    func currenciesExceptBase() -> [String] {
        var currenciesExceptBase = currencies
        currenciesExceptBase.remove(at: pickerFrom.selectedRow(inComponent: 0))
        
        return currenciesExceptBase
    }
    
    // MARK Networking
    
    func requestCurrentCurrencyRate() {
        self.activityIndicator.startAnimating()
        self.label.text = ""
        
        let baseCurrencyIndex = self.pickerFrom.selectedRow(inComponent: 0)
        let toCurrencyIndex = self.pickerTo.selectedRow(inComponent: 0)
        
        let baseCurrency = self.currencies[baseCurrencyIndex]
        let toCurrency = self.currenciesExceptBase()[toCurrencyIndex]
        
        self.retrieveCurrencyRate(baseCurrency: baseCurrency, toCurrency: toCurrency){[weak self] (value) in
            DispatchQueue.main.async(execute: {
                if let strongSelf = self {
                    strongSelf.label.text = value
                    strongSelf.activityIndicator.stopAnimating()
                }
            })
        }
    }
    
    func retrieveCurrencyRate(baseCurrency: String, toCurrency: String, completion: @escaping (String) -> Void) {
        self.requestCurrencyRates(baseCurrency: baseCurrency) { [weak self] (data, error) in
            var string = "No currency retrieved!"
            
            if let currentError = error {
                string = currentError.localizedDescription
            } else {
                if let stringSelf = self {
                    string = stringSelf.parseCurrencyRatesResponse(data: data, toCurrency: toCurrency)
                }
            }
            completion(string)
        }
    }
    
    func parseCurrencyRatesResponse(data: Data?, toCurrency: String) -> String{
        var value: String = ""
        
        do{
            let json = try JSONSerialization.jsonObject(with: data!, options: []) as? Dictionary<String, Any>
            if let parsedJson = json {
                print("\(parsedJson)")
                if let rates = parsedJson["rates"] as? Dictionary<String, Double>{
                    if let rate = rates[toCurrency] {
                        value = "\(rate)"
                    } else {
                        value = "No rate for currency \"\(toCurrency)\" found"
                    }
                } else {
                    value = "No \"rate\" for currency"
                }
            } else {
                value = "No JSON value parsed"
            }
        } catch {
            value = error.localizedDescription
        }
        
        return value
    }
    
    func requestCurrencyRates(baseCurrency: String, parseHandler: @escaping (Data?, Error?) -> Void){
        let url = URL(string: "https://api.fixer.io/latest?base=" + baseCurrency)!
        
        let dataTask = URLSession.shared.dataTask(with: url){
            (dataReceived, response, error) in
            parseHandler(dataReceived, error)
        }
        
        dataTask.resume()
    }
    
    func requestCurrentCurrencyCodes() {
        self.retrieveCurrencyCodes(){[weak self] (value) in
            DispatchQueue.main.async(execute: {
                if let strongSelf = self {
                    strongSelf.currencies = value
                    strongSelf.pickerFrom.reloadAllComponents()
                    strongSelf.pickerTo.reloadAllComponents()
                }
            })
        }
    }
    
    func retrieveCurrencyCodes(completion: @escaping ([String]) -> Void) {
        self.requestCurrencyCodes() { [weak self] (data, error) in
            var codes = [String]()
    
            if let currentError = error {
                // Если нет интернета, то заполняем значениями по умолчанию
                codes = ViewController.defualtCodes
                print(currentError.localizedDescription)
            } else {
                if let stringSelf = self {
                    codes = stringSelf.parseCurrencyCodesResponse(data: data)
                }
            }
            print(codes)
            completion(codes)
        }
    }
    
    func parseCurrencyCodesResponse(data: Data?) -> [String]{
        var value = [String]()
        
        do{
            let json = try JSONSerialization.jsonObject(with: data!, options: []) as? Dictionary<String, Any>
            if let parsedJson = json {
                if let defaultBase = parsedJson["base"] as? String {
                    value.append(defaultBase)
                } else {
                    print("No base for currency")
                }
            
                if let rates = parsedJson["rates"] as? Dictionary<String, Double>{
                    value += rates.keys
                } else {
                    print("No rates for currency")
                }
            } else {
                print("No JSON value parsed")
            }
        } catch {
            print(error.localizedDescription)
        }
        
        return value
    }
    
    func requestCurrencyCodes(parseHandler: @escaping (Data?, Error?) -> Void){
        let url = URL(string: "https://api.fixer.io/latest")!
        
        let dataTask = URLSession.shared.dataTask(with: url){
            (dataReceived, response, error) in
            parseHandler(dataReceived, error)
        }
        
        dataTask.resume()
    }
}

