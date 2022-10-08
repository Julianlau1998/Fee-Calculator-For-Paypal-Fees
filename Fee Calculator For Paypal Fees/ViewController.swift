//
//  ViewController.swift
//  test
//
//  Created by Julian Lau on 06.02.22.
//

import UIKit
import GoogleMobileAds
import WebKit

class ViewController: UIViewController, GADFullScreenContentDelegate {
    
    private let banner: GADBannerView = {
        let banner = GADBannerView()
        banner.adUnitID = "ca-app-pub-1006221991146598/2293592475"
        banner.load(GADRequest())
        banner.backgroundColor  = .secondarySystemBackground
        return banner
    }()
    
    private let webView: WKWebView = {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor  = .secondarySystemBackground
        return webView
    }()
    var interstitial: GADInterstitialAd?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // add banner ad
        banner.rootViewController = self
        view.addSubview(banner)
        
        view.addSubview(webView)
        
        let statusBarView = UIView(frame: UIApplication.shared.statusBarFrame)
        let statusBarColor = UIColor(red: 42/255, green: 52/255, blue: 60/255, alpha: 1.0)
        statusBarView.frame.size.width = 10000
        banner.backgroundColor  = UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1.0)
        view.addSubview(statusBarView)

        guard let url = URL(string: "https://paypal-fee-calculator.netlify.app/") else {
            return
        }
        webView.load(URLRequest(url: url))
        
        // load interstitial ad
        loadInterstitial()
        var interstitalTimer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(ViewController.showInterstitial), userInfo: nil, repeats: true)

         self.view.backgroundColor = .black
    }
    
    @objc func loadInterstitial() {
        let request = GADRequest()
            GADInterstitialAd.load(
              withAdUnitID: "ca-app-pub-1006221991146598/5245309702", request: request
            ) { (ad, error) in
              if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                return
              }
              self.interstitial = ad
              self.interstitial?.fullScreenContentDelegate = self
            }
    }
    
    @objc func showInterstitial()
    {
        if self.interstitial != nil {
            self.interstitial?.present(fromRootViewController: self)
            } else {
                NSLog("Ad wasn't ready")
            }
        
        loadInterstitial()
    }

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        banner.frame = CGRect(x: 0, y:view.frame.size.height-120, width: view.frame.size.width, height: 100).integral
        webView.frame = CGRect(x: 0, y:0, width: view.frame.size.width, height: view.frame.size.height-120)
    }

}
