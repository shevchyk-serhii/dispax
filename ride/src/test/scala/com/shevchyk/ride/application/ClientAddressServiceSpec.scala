package com.shevchyk.ride.application

import com.shevchyk.core.domain.PersonId
import com.shevchyk.ride.domain.{ClientAddress, ClientAddressId, SaveClientAddressRequest}
import com.shevchyk.ride.application.service.{ClientAddressService, ClientAddressServiceImpl}
import com.shevchyk.ride.repository.ClientAddressRepository
import com.shevchyk.ride.repository.helpers.InMemoryClientAddressRepository
import zio.*
import zio.test.*
import java.util.UUID

object ClientAddressServiceSpec extends ZIOSpecDefault {

  val clientId  = PersonId(UUID.fromString("00000001-0000-0000-0000-000000000001"))
  val clientId2 = PersonId(UUID.fromString("00000001-0000-0000-0000-000000000002"))

  val testLayer = InMemoryClientAddressRepository.layer >>> ZLayer.fromFunction(ClientAddressServiceImpl(_))

  def req(address: String, label: String = "Home") = SaveClientAddressRequest(label = label, address = address)

  def spec =
    suite("ClientAddressService")(
      suite("getAddresses")(
        test("returns empty list for new client") {
          for {
            svc  <- ZIO.service[ClientAddressService]
            list <- svc.getAddresses(clientId)
          } yield assertTrue(list.isEmpty)
        },
        test("returns only addresses for requested client") {
          for {
            svc <- ZIO.service[ClientAddressService]
            _   <- svc.saveAddress(clientId, req("Street A"))
            _   <- svc.saveAddress(clientId2, req("Street B"))
            res <- svc.getAddresses(clientId)
          } yield assertTrue(res.length == 1 && res.head.address == "Street A")
        }
      ),
      suite("saveAddress")(
        test("creates new address when not existing") {
          for {
            svc  <- ZIO.service[ClientAddressService]
            addr <- svc.saveAddress(clientId, req("New Street 1", "Work"))
          } yield assertTrue(
            addr.address == "New Street 1",
            addr.label == "Work",
            addr.clientId == clientId,
            addr.useCount == 1
          )
        },
        test("increments useCount for duplicate address instead of creating new") {
          for {
            svc  <- ZIO.service[ClientAddressService]
            _    <- svc.saveAddress(clientId, req("Repeated Street"))
            _    <- svc.saveAddress(clientId, req("Repeated Street"))
            list  <- svc.getAddresses(clientId)
          } yield assertTrue(
            list.length == 1,
            list.head.useCount == 2
          )
        },
        test("saves with coordinates when provided") {
          for {
            svc  <- ZIO.service[ClientAddressService]
            addr <- svc.saveAddress(clientId, SaveClientAddressRequest("Home", "Main St", Some(48.1), Some(11.5)))
          } yield assertTrue(
            addr.latitude.contains(48.1),
            addr.longitude.contains(11.5)
          )
        },
        test("same address for different clients creates separate entries") {
          for {
            svc <- ZIO.service[ClientAddressService]
            _   <- svc.saveAddress(clientId, req("Shared Street"))
            _   <- svc.saveAddress(clientId2, req("Shared Street"))
            l1  <- svc.getAddresses(clientId)
            l2  <- svc.getAddresses(clientId2)
          } yield assertTrue(l1.length == 1, l2.length == 1)
        }
      ),
      suite("recordUsage")(
        test("increments useCount for existing address") {
          for {
            svc  <- ZIO.service[ClientAddressService]
            _    <- svc.saveAddress(clientId, req("Track Street"))
            _    <- svc.recordUsage(clientId, "Track Street", "Home", None, None)
            list <- svc.getAddresses(clientId)
          } yield assertTrue(list.head.useCount == 2)
        },
        test("creates new address when not existing") {
          for {
            svc  <- ZIO.service[ClientAddressService]
            _    <- svc.recordUsage(clientId, "New Usage Street", "Office", Some(48.0), Some(11.0))
            list <- svc.getAddresses(clientId)
          } yield assertTrue(
            list.length == 1,
            list.head.address == "New Usage Street",
            list.head.label == "Office"
          )
        },

        // ─── Mutation-kill: lat/lng swap and useCount=999 in create branch ─────

        test("recordUsage create-branch stores correct latitude, longitude (not swapped) and useCount=1") {
          // Mutants: swap lat→lng/lng→lat assignments, or set useCount to a wrong constant.
          // This test pins exact field values so those mutations are killed.
          for {
            svc  <- ZIO.service[ClientAddressService]
            _    <- svc.recordUsage(clientId, "Coord Check Street", "Home", Some(52.5), Some(13.4))
            list <- svc.getAddresses(clientId)
          } yield assertTrue(
            list.length == 1,
            // latitude and longitude must NOT be swapped
            list.head.latitude.contains(52.5),
            list.head.longitude.contains(13.4),
            // initial useCount must be 1 (ClientAddress default), not 0 or any other value
            list.head.useCount == 1
          )
        }
      ),
      suite("deleteAddress")(
        test("deletes own address and returns true") {
          for {
            svc    <- ZIO.service[ClientAddressService]
            addr   <- svc.saveAddress(clientId, req("To Delete"))
            result <- svc.deleteAddress(addr.id, clientId)
            list   <- svc.getAddresses(clientId)
          } yield assertTrue(result, list.isEmpty)
        },
        test("returns false when address not found") {
          for {
            svc    <- ZIO.service[ClientAddressService]
            result <- svc.deleteAddress(ClientAddressId.generate(), clientId)
          } yield assertTrue(!result)
        },
        test("cannot delete another client's address") {
          for {
            svc    <- ZIO.service[ClientAddressService]
            addr   <- svc.saveAddress(clientId, req("Protected"))
            result <- svc.deleteAddress(addr.id, clientId2)
            list   <- svc.getAddresses(clientId)
          } yield assertTrue(!result, list.length == 1)
        }
      )
    ).provide(testLayer) @@ TestAspect.sequential
}
