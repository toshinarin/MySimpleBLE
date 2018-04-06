//
//  ViewController.swift
//  MySimpleBLE
//
//  Created by Toshinari Nakamura on 2017/10/27.
//  Copyright © 2017年 toshinari.nakamura. All rights reserved.
//
//  Reference: https://qiita.com/eKushida/items/def628e0eff6c106d467
//             堤 修一・松村 礼央（2015）iOS×BLE Core Bluetoothプログラミング ソシム.

import UIKit
import CoreBluetooth

//Central : 本アプリ
//Peripheral : ESP32
final class ViewController: UIViewController {
    @IBOutlet private weak var messageTextField: UITextField!

    // GATTサービス https://www.bluetooth.com/ja-jp/specifications/gatt/services
    let kServiveUUIDESP32 = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"

    // Attribute Types (UUIDs)
    let kCharacteristcUUIDESP32EpaperWriter = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    private var serviceUUID : CBUUID!
    private var charcteristicUUID: CBUUID!
    private var epaperCharacteristic: CBCharacteristic?

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    /// セントラルマネージャー、UUIDの初期化
    private func setup() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        serviceUUID = CBUUID(string: kServiveUUIDESP32)
        charcteristicUUID = CBUUID(string: kCharacteristcUUIDESP32EpaperWriter)
    }

    @IBAction func startScan(_ sender: Any) {
        scanForPeripherals()
    }

    @IBAction func sendMessage(_ sender: Any) {
        print("sending data")
        guard let c = self.epaperCharacteristic else {
            return
        }
        let string = messageTextField.text ?? ""
        let data = string.data(using: String.Encoding.utf8)
        self.peripheral.writeValue(data!, for: c,type: CBCharacteristicWriteType.withResponse)
    }

    private func scanForPeripherals() {
        centralManager.scanForPeripherals(withServices: nil,
                                          options: nil)
    }
}

//MARK : - CBCentralManagerDelegate
extension ViewController: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("central manager [\(centralManager)] state: \(central.state)")

        switch central.state {
        // 電源ONを待って、スキャンする
        case CBManagerState.poweredOn:
            scanForPeripherals()
        default:
            break
        }
    }

    /// ペリフェラルを発見すると呼ばれる
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        guard let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String else { return }
        if name != "ESP32 E-paper Service" {
            return
        }
        self.peripheral = peripheral
        print("services: \(peripheral)")

        centralManager.stopScan()

        //接続開始
        print("link start")
        central.connect(peripheral, options: nil)
    }

    /// 接続されると呼ばれる
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
}

//MARK : - CBPeripheralDelegate
extension ViewController: CBPeripheralDelegate {

    /// サービス発見時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {

        if error != nil {
            print("failed to discover services. error: \(error.debugDescription)")
            return
        }

        guard let services = peripheral.services else {
            print("no services for peripheral: \(peripheral)")
            return
        }

        guard let service = services.first else {
            print("services length zero")
            return
        }

        //キャラクタリスティック探索開始
        print("discover characteristics for peripheral \(peripheral) start")
        peripheral.discoverCharacteristics([charcteristicUUID],
                                           for: service)
    }

    /// キャラクタリスティック発見時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {

        if error != nil {
            print("failed to discover characteristics. error: \(error.debugDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            print("no characteristics for peripheral: \(peripheral)")
            return
        }

        for characteristic in characteristics {
            if (characteristic.uuid.uuidString != kCharacteristcUUIDESP32EpaperWriter) {
                continue
            }
            print("epaperCharacteristic: \(characteristic)")
            self.epaperCharacteristic = characteristic

            let date = Date()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateStr = formatter.string(from: date)
            let string = "connected from iPhone [\(dateStr)]"
            let data = string.data(using: String.Encoding.ascii)

            print("sending data")
            peripheral.writeValue(data!, for: characteristic,type: CBCharacteristicWriteType.withResponse)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        if error != nil {
            print("failed to write value. error: \(error.debugDescription)")
            return
        }

        print("finish write data")
    }
}

