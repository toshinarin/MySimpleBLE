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

// Central : 本アプリ
// Peripheral : ESP32
final class ViewController: UIViewController {
    @IBOutlet private weak var messageTextField: UITextField!

    // GATTサービス https://www.bluetooth.com/ja-jp/specifications/gatt/services
    let serviveUUIDESP32 = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    let characteristcUUIDESP32EpaperWriter = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var epaperCharacteristic: CBCharacteristic?

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @IBAction func startScan(_ sender: Any) {
        scanForPeripherals()
    }

    @IBAction func sendMessage(_ sender: Any) {
        print("sending data")
        guard let characteristic = self.epaperCharacteristic else { return }
        guard let peripheral = self.peripheral else { return }

        let message = messageTextField.text ?? ""
        guard let data = message.data(using: String.Encoding.utf8) else { return }

        peripheral.writeValue(data,
                              for: characteristic,
                              type: CBCharacteristicWriteType.withResponse)
        print("sent data")
    }

    private func setup() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
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
        let nameData = advertisementData[CBAdvertisementDataLocalNameKey]
        guard let name = nameData as? String else { return }
        guard name == "ESP32 E-paper Service" else { return }

        self.peripheral = peripheral
        print("peripheral: \(peripheral)")

        central.stopScan()
        central.connect(peripheral, options: nil)
        print("link start")
    }

    /// 接続されると呼ばれる
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        let serviceUUID = CBUUID(string: serviveUUIDESP32)
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
        let charcteristicUUID = CBUUID(string: characteristcUUIDESP32EpaperWriter)
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
            if (characteristic.uuid.uuidString != characteristcUUIDESP32EpaperWriter) {
                continue
            }
            print("sending data")
            print("epaperCharacteristic: \(characteristic)")
            self.epaperCharacteristic = characteristic

            // 電子ペーパーに書き込むメッセージ
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateStr = formatter.string(from: Date())
            let message = "connected from iPhone [\(dateStr)]"
            guard let data = message.data(using: String.Encoding.ascii) else { return }

            peripheral.writeValue(data,
                                  for: characteristic,
                                  type: CBCharacteristicWriteType.withResponse)
            print("sent data")
            break
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

