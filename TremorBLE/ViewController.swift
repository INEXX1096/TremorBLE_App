import UIKit
import CoreBluetooth
import UserNotifications

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    var tremorCharacteristic: CBCharacteristic?

    @IBOutlet var tremorProgressView: UIView!
    @IBOutlet weak var tremorLabel: UILabel!

    // ✅ 你的服务和特征 UUID（根据你提供的 UUID 修改）
    let targetServiceUUID = CBUUID(string: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2")
    let targetCharacteristicUUID = CBUUID(string: "0xBEFC5C1C-A5D0-42DB-A6C2-C0BFA020E50D")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }

    // MARK: - Bluetooth State
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("✅ Bluetooth is on. Scanning for peripherals...")
            centralManager.scanForPeripherals(withServices: nil)
        } else {
            print("❌ Bluetooth not available. State: \(central.state.rawValue)")
        }
    }

    // MARK: - Discover
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("🔍 Discovered peripheral: \(peripheral.name ?? "Unknown"), UUID: \(peripheral.identifier)")

        
        if peripheral.name == "TremorBLE" {
            print("✅ Found TremorBLE device. Connecting...")
            self.peripheral = peripheral
            self.peripheral?.delegate = self
            centralManager.stopScan()
            centralManager.connect(peripheral, options: nil)
        }
    }

    // MARK: - Connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.name ?? "device")")
        peripheral.discoverServices([targetServiceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                print("📦 Found service: \(service.uuid)")
                if service.uuid == targetServiceUUID {
                    peripheral.discoverCharacteristics([targetCharacteristicUUID], for: service)
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                print("📌 Found characteristic: \(characteristic.uuid)")
                if characteristic.uuid == targetCharacteristicUUID {
                    tremorCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("✅ Subscribed to tremor characteristic")
                }
            }
        }
    }

    // MARK: - Receive Data
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == targetCharacteristicUUID {
            if let value = characteristic.value {
                guard value.count >= 2 else {
                    print("❌ Received value too short")
                    return
                }

                let rawValue = UInt16(value[0]) | (UInt16(value[1]) << 8)
                print("📥 Received raw value: \(String(format: "0x%04X", rawValue))")

                DispatchQueue.main.async {
                    switch rawValue {
                    case 0x001:
                        self.tremorLabel.text = "Tremor Detected"
                        

                    case 0x0200:
                        self.tremorLabel.text = "Dyskinesia Detected"
                    
                    case 0x0201:
                        self.tremorLabel.text = "Dyskinesia Detected"
                        self.tremorLabel.text = "Tremor Detected"

                    default:
                        self.tremorLabel.text = "Unknown State: \(String(format: "0x%04X", rawValue))"
                    }
                }
            }
        }
    }


    // MARK: - Error Handling
    func peripheral(_ peripheral: CBPeripheral, didFailToConnect error: Error?) {
        print("❌ Failed to connect to peripheral: \(error?.localizedDescription ?? "Unknown error")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("❌ Disconnected from peripheral: \(peripheral.name ?? "Unknown")")
    }
    
    
    // Notification
    func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    
    

    
}
