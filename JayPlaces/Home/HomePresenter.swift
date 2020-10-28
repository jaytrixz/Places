//
//  HomePresenter.swift
//  JayPlaces
//
//  Created by John Joseph M. Santos on 10/26/20.
//

import Foundation
import CoreData

protocol HomePresenterProtocol {
    func presenterShouldInitializeCoreData()
}

struct HomePresenter: HomePresenterProtocol {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var context: NSManagedObjectContext!

    func presenterShouldInitializeCoreData() {
        context = appDelegate.persistentContainer.viewContext

        
    }
}
